import UIKit
import Foundation

/// Renders a modern, single-page visual PDF report from `ReportData`.
final class ReportPDFGenerator {
    
    private static let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792) // US Letter
    private static let margin: CGFloat = 40
    private static let contentWidth = pageRect.width - 2 * margin
    
    // Color scheme
    private static let greenColor = UIColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0)
    private static let yellowColor = UIColor(red: 0.9, green: 0.7, blue: 0.1, alpha: 1.0)
    private static let redColor = UIColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1.0)
    private static let grayColor = UIColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 1.0)
    
    /// Generates a PDF file and returns its file URL.
    static func generatePDF(from report: ReportData) -> URL? {
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        
        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            
            // Header section
            drawHeader(report: report, ctx: ctx)
            
            // Main wellness score with wellness badges
            let wellnessScoreEndY = drawCentralWellnessScore(report: report, ctx: ctx)
            
            // NEW LAYOUT: Two-column top section
            let topSectionEndY = drawTwoColumnTopSection(report: report, startY: wellnessScoreEndY + 15, ctx: ctx)
            
            // NEW LAYOUT: Two full-width stacked sections
            let nutritionEndY = drawNutritionSection(report: report, startY: topSectionEndY + 20, ctx: ctx)
            _ = drawExerciseSleepSection(report: report, startY: nutritionEndY + 15, ctx: ctx)
            
        }
        
        guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let fileName = "wellness-report-\(UUID().uuidString).pdf"
        let url = documents.appendingPathComponent(fileName)
        
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            print("Failed to write PDF: \(error)")
            return nil
        }
    }
    
    // MARK: - Drawing Functions
    
    private static func drawHeader(report: ReportData, ctx: UIGraphicsPDFRendererContext) {
        let headerY: CGFloat = margin
        
        // Nickname
        let nicknameAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 20),
            .foregroundColor: UIColor.black
        ]
        let nicknameString = NSAttributedString(string: report.nickname, attributes: nicknameAttributes)
        nicknameString.draw(at: CGPoint(x: margin, y: headerY))
        
        // Date range
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "fi_FI")
        let dateRange = "\(formatter.string(from: report.startDate)) - \(formatter.string(from: report.endDate))"
        
        let dateAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12),
            .foregroundColor: grayColor
        ]
        let dateString = NSAttributedString(string: dateRange, attributes: dateAttributes)
        let dateSize = dateString.boundingRect(with: CGSize(width: contentWidth, height: 20), options: .usesLineFragmentOrigin, context: nil)
        dateString.draw(at: CGPoint(x: pageRect.width - margin - dateSize.width, y: headerY + 5))
    }
    
    private static func drawCentralWellnessScore(report: ReportData, ctx: UIGraphicsPDFRendererContext) -> CGFloat {
        let centerY: CGFloat = 110
        let largeDiameter: CGFloat = 68
        let largeToSmallSpacing: CGFloat = 28
        let baseSmallDiameter: CGFloat = 36
        let baseSmallSpacing: CGFloat = 16

        let smallMetrics: [(title: String, score: Int?)] = [
            (title: "Meal Impact", score: report.mealImpactAverage),
            (title: "Glukoosi", score: report.glucoseScoreAverage),
            (title: "Liikunta", score: report.stepDataDays > 0 ? Int(round(report.activityScoreAverage)) : nil),
            (title: "Uni", score: report.sleepScoreAverage)
        ]

        let wellnessCenter = CGPoint(x: pageRect.midX, y: centerY)
        drawScoreCircle(center: wellnessCenter, diameter: largeDiameter, score: report.wellnessScore, isPrimary: true)

        let primaryLabelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: UIColor.black
        ]
        let primaryLabel = NSAttributedString(string: "Wellness Score", attributes: primaryLabelAttributes)
        let primaryLabelSize = primaryLabel.boundingRect(
            with: CGSize(width: largeDiameter + 40, height: .greatestFiniteMagnitude),
            options: .usesLineFragmentOrigin,
            context: nil
        )
        let primaryLabelOrigin = CGPoint(
            x: wellnessCenter.x - primaryLabelSize.width / 2,
            y: centerY + largeDiameter / 2 + 8
        )
        primaryLabel.draw(at: primaryLabelOrigin)

        var maxLabelBottom: CGFloat = primaryLabelOrigin.y + primaryLabelSize.height

        let availableWidthToRight = max(0, (pageRect.width - margin) - (wellnessCenter.x + largeDiameter / 2 + largeToSmallSpacing))
        let smallMetricCount = CGFloat(smallMetrics.count)
        let metricSpacingCount = max(CGFloat(0), smallMetricCount - 1)
        var smallSpacing = baseSmallSpacing
        var smallDiameter = baseSmallDiameter
        let requiredWidth = smallMetricCount * smallDiameter + metricSpacingCount * smallSpacing
        var useBadgeLayout = false

        if availableWidthToRight <= 0 {
            useBadgeLayout = true
        } else if requiredWidth > availableWidthToRight {
            if metricSpacingCount > 0 {
                let maxSpacing = max(CGFloat(6), min(smallSpacing, availableWidthToRight / metricSpacingCount))
                let spacingWidth = maxSpacing * metricSpacingCount
                let remainingWidth = availableWidthToRight - spacingWidth
                if remainingWidth > 0 {
                    smallDiameter = max(CGFloat(22), remainingWidth / smallMetricCount)
                    smallSpacing = maxSpacing
                    if smallDiameter < 24 {
                        useBadgeLayout = true
                    }
                } else {
                    useBadgeLayout = true
                }
            } else {
                smallDiameter = min(baseSmallDiameter, availableWidthToRight)
                if smallDiameter < 24 {
                    useBadgeLayout = true
                }
            }
        }

        if !useBadgeLayout {
            for (index, metric) in smallMetrics.enumerated() {
                let firstCenterX = wellnessCenter.x + largeDiameter / 2 + largeToSmallSpacing + smallDiameter / 2
                let centerX = firstCenterX + CGFloat(index) * (smallDiameter + smallSpacing)
                let center = CGPoint(x: centerX, y: centerY)
                drawScoreCircle(center: center, diameter: smallDiameter, score: metric.score, isPrimary: false)

                let labelAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 10),
                    .foregroundColor: UIColor.black
                ]
                let labelString = NSAttributedString(string: metric.title, attributes: labelAttributes)
                let labelSize = labelString.boundingRect(
                    with: CGSize(width: smallDiameter + 30, height: .greatestFiniteMagnitude),
                    options: .usesLineFragmentOrigin,
                    context: nil
                )
                let labelOrigin = CGPoint(
                    x: center.x - labelSize.width / 2,
                    y: centerY + smallDiameter / 2 + 6
                )
                labelString.draw(at: labelOrigin)

                maxLabelBottom = max(maxLabelBottom, labelOrigin.y + labelSize.height)
            }

            return maxLabelBottom + 12
        }

        // Fallback badge layout positioned underneath the primary score when there isn't enough space for circles
        let badgesTop = maxLabelBottom + 18
        let badgeWidth: CGFloat = 115
        let badgeHeight: CGFloat = 48
        let badgeSpacing: CGFloat = 14
        let totalWidth = CGFloat(smallMetrics.count) * badgeWidth + CGFloat(smallMetrics.count - 1) * badgeSpacing
        let startX = max(margin, wellnessCenter.x - totalWidth / 2)

        for (index, metric) in smallMetrics.enumerated() {
            let originX = startX + CGFloat(index) * (badgeWidth + badgeSpacing)
            drawBadge(title: metric.title, score: metric.score, rect: CGRect(x: originX, y: badgesTop, width: badgeWidth, height: badgeHeight))
        }

        return badgesTop + badgeHeight + 10
    }

    private static func drawScoreCircle(center: CGPoint, diameter: CGFloat, score: Int?, isPrimary: Bool) {
        let circleRect = CGRect(
            x: center.x - diameter / 2,
            y: center.y - diameter / 2,
            width: diameter,
            height: diameter
        )

        let fillColor: UIColor
        if let score {
            fillColor = colorForScore(score)
        } else {
            fillColor = grayColor.withAlphaComponent(0.4)
        }
        fillColor.setFill()
        UIBezierPath(ovalIn: circleRect).fill()

        let text = score.map { "\($0)" } ?? "–"
        let fontSize: CGFloat = isPrimary ? 22 : 14
        let textAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: fontSize),
            .foregroundColor: score != nil ? UIColor.white : UIColor.darkGray
        ]
        let textString = NSAttributedString(string: text, attributes: textAttributes)
        let textSize = textString.boundingRect(
            with: CGSize(width: diameter, height: diameter),
            options: .usesLineFragmentOrigin,
            context: nil
        )
        let textOrigin = CGPoint(
            x: center.x - textSize.width / 2,
            y: center.y - textSize.height / 2
        )
        textString.draw(at: textOrigin)
    }

    private static func drawBadge(title: String, score: Int?, rect: CGRect) {
        let badgePath = UIBezierPath(roundedRect: rect, cornerRadius: 12)
        if let score {
            let color = colorForScore(score)
            color.withAlphaComponent(0.18).setFill()
            badgePath.fill()
            color.withAlphaComponent(0.5).setStroke()
        } else {
            grayColor.withAlphaComponent(0.15).setFill()
            badgePath.fill()
            grayColor.withAlphaComponent(0.3).setStroke()
        }
        badgePath.lineWidth = 1
        badgePath.stroke()

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10, weight: .medium),
            .foregroundColor: UIColor.black
        ]
        let titleString = NSAttributedString(string: title, attributes: titleAttributes)
        titleString.draw(at: CGPoint(x: rect.minX + 8, y: rect.minY + 6))

        let valueText = score.map { "\($0)" } ?? "–"
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 16),
            .foregroundColor: score != nil ? UIColor.black : grayColor
        ]
        let valueString = NSAttributedString(string: valueText, attributes: valueAttributes)
        let valueSize = valueString.boundingRect(with: CGSize(width: rect.width - 12, height: rect.height), options: .usesLineFragmentOrigin, context: nil)
        valueString.draw(at: CGPoint(x: rect.minX + (rect.width - valueSize.width)/2, y: rect.maxY - valueSize.height - 8))
    }
    
    private static func drawTwoColumnTopSection(report: ReportData, startY: CGFloat, ctx: UIGraphicsPDFRendererContext) -> CGFloat {
        // Left column (1/3 width): Verensokeri metrics
        let leftColumnWidth = contentWidth / 3
        let rightColumnWidth = contentWidth * 2 / 3
        let columnSpacing: CGFloat = 20
        
        let leftColumnX = margin
        let rightColumnX = margin + leftColumnWidth + columnSpacing
        
        // Draw Verensokeri column
        let leftEndY = drawEnhancedBloodSugarColumn(report: report, x: leftColumnX, y: startY, width: leftColumnWidth, ctx: ctx)
        
        // Draw AGP chart in right column
        let rightEndY = drawAGPChart(report: report, x: rightColumnX, y: startY, width: rightColumnWidth - columnSpacing, ctx: ctx)
        
        // Return the maximum Y coordinate
        return max(leftEndY, rightEndY + startY)
    }
    
    private static func drawNutritionSection(report: ReportData, startY: CGFloat, ctx: UIGraphicsPDFRendererContext) -> CGFloat {
        var currentY = startY
        
        // Section header
        currentY += drawSectionHeader("Ravinto", x: margin, y: currentY, width: contentWidth)
        
        // Left side: Traditional metrics
        let leftWidth = contentWidth / 2 - 10
        let rightWidth = contentWidth / 2 - 10
        let rightX = margin + leftWidth + 20
        
        var leftY = currentY
        var rightY = currentY
        
        // Left: Meal score and macro distribution
        leftY += drawMetricRowWithTarget("Ateriapisteen ka.", value: "\(report.mealScoreAverage)", score: report.mealScoreAverage, target: "Tavoite: >80", x: margin, y: leftY, width: leftWidth)
        leftY += 10
        leftY += drawMacroPieChart(macros: report.macroDistribution, x: margin, y: leftY, width: leftWidth)
        leftY += drawTargetText("Suositus: H 45-55%, P 15-25%, R 25-35%", x: margin, y: leftY, width: leftWidth)
        
        // Right: Energy distribution by time of day
        rightY += drawEnergyDistributionChart(distribution: report.energyDistribution, x: rightX, y: rightY, width: rightWidth)
        
        return max(leftY, rightY) + 8
    }
    
    private static func drawExerciseSleepSection(report: ReportData, startY: CGFloat, ctx: UIGraphicsPDFRendererContext) -> CGFloat {
        var currentY = startY
        
        // Section header  
        currentY += drawSectionHeader("Liikunta & Uni", x: margin, y: currentY, width: contentWidth)
        
        // Left side: Activity metrics
        let leftWidth = contentWidth / 2 - 10
        let rightWidth = contentWidth / 2 - 10
        let rightX = margin + leftWidth + 20
        
        var leftY = currentY
        var rightY = currentY
        
        // Enhanced activity metrics
        leftY += drawMetricRowWithTarget("Askeleet ka.", value: String(format: "%.0f", report.averageSteps), score: Int(report.activityScoreAverage), target: "Tavoite: >8000", x: margin, y: leftY, width: leftWidth)
        leftY += drawMetricRowWithTarget("Datapäivät", value: "\(report.stepDataDays)", score: report.stepDataDays * 5, target: "", x: margin, y: leftY, width: leftWidth)
        
        // Step goal achievements
        if !report.stepGoalAchievements.isEmpty {
            leftY += 8
            leftY += drawStepGoalAchievements(achievements: report.stepGoalAchievements, x: margin, y: leftY, width: leftWidth)
        }
        
        // Sleep metrics with targets
        if let sleepScore = report.sleepScoreAverage {
            rightY += drawMetricRowWithTarget("Unen laatu", value: "\(sleepScore)", score: sleepScore, target: "Tavoite: >80", x: rightX, y: rightY, width: rightWidth)
        }
        
        if let sleepDuration = report.averageSleepDurationHours {
            let durationScore = sleepDuration >= 7.0 && sleepDuration <= 9.0 ? 80 : 50
            rightY += drawMetricRowWithTarget("Unen kesto", value: String(format: "%.1fh", sleepDuration), score: durationScore, target: "Tavoite: 7-9h", x: rightX, y: rightY, width: rightWidth)
        }
        
        if let regularityScore = report.sleepRegularityScore {
            rightY += drawMetricRowWithTarget("Säännöllisyys", value: "\(regularityScore)", score: regularityScore, target: "Tavoite: >70", x: rightX, y: rightY, width: rightWidth)
        }
        
        return max(leftY, rightY) + 8
    }
    
    private static func drawEnhancedBloodSugarColumn(report: ReportData, x: CGFloat, y: CGFloat, width: CGFloat, ctx: UIGraphicsPDFRendererContext) -> CGFloat {
        var currentY = y
        
        // Column header
        currentY += drawColumnHeader("Verensokeri", x: x, y: currentY, width: width)
        
        if let metrics = report.glucoseMetrics {
            // Enhanced metrics with target values
            currentY += drawMetricRowWithTarget("Aika tavoitteessa", value: "\(Int(metrics.tir))%", score: Int(metrics.tir), target: "Tavoite: >70%", x: x, y: currentY, width: width)
            
            // TITR with target: green if >= 50%, red otherwise
            let titrScore = metrics.titr >= 50.0 ? 80 : 30
            currentY += drawMetricRowWithTarget("TITR", value: "\(Int(metrics.titr))%", score: titrScore, target: "Tavoite: >50%", x: x, y: currentY, width: width)
            
            currentY += drawMetricRowWithTarget("Aika alle 3,9", value: "\(Int(metrics.tbr))%", score: 100 - Int(metrics.tbr), target: "Tavoite: <5%", x: x, y: currentY, width: width)
            currentY += drawMetricRowWithTarget("Aika yli 10,0", value: "\(Int(metrics.tar))%", score: 100 - Int(metrics.tar), target: "Tavoite: <25%", x: x, y: currentY, width: width)
            currentY += drawMetricRowWithTarget("CV", value: String(format: "%.1f%%", metrics.cv), score: metrics.cv < 36 ? 80 : 50, target: "Tavoite: <36%", x: x, y: currentY, width: width)
            
            if let postMealAvg = report.postMealGlucoseAverage {
                // "Ateria 2h ka." with target values
                let postMealScore: Int
                if postMealAvg >= 4.0 && postMealAvg <= 10.0 {
                    postMealScore = 80 // Green
                } else if postMealAvg < 4.0 {
                    postMealScore = 30 // Red
                } else {
                    postMealScore = 65 // Yellow
                }
                currentY += drawMetricRowWithTarget("Ateria 2h ka.", value: String(format: "%.1f", postMealAvg), score: postMealScore, target: "Tavoite: 4-10", x: x, y: currentY, width: width)
            }
            
            // NEW: Post-meal success rate
            if let successRate = report.postMealSuccessRate {
                let successScore = successRate >= 70.0 ? 80 : (successRate >= 50.0 ? 65 : 30)
                currentY += drawMetricRowWithTarget("Aterianjälkeiset onnistumiset", value: String(format: "%.0f%%", successRate), score: successScore, target: "Tavoite: >70%", x: x, y: currentY, width: width)
            }
            
        } else {
            currentY += drawNoDataMessage("Ei glukoosidataa", x: x, y: currentY, width: width)
        }
        
        return currentY
    }
    
    // MARK: - Helper Drawing Functions
    
    private static func drawColumnHeader(_ title: String, x: CGFloat, y: CGFloat, width: CGFloat) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 14),
            .foregroundColor: UIColor.black
        ]
        let string = NSAttributedString(string: title, attributes: attributes)
        string.draw(at: CGPoint(x: x, y: y))
        
        // Draw underline
        let lineY = y + 20
        let path = UIBezierPath()
        path.move(to: CGPoint(x: x, y: lineY))
        path.addLine(to: CGPoint(x: x + width, y: lineY))
        grayColor.setStroke()
        path.lineWidth = 1
        path.stroke()
        
        return 25
    }

    private static func drawSectionHeader(_ title: String, x: CGFloat, y: CGFloat, width: CGFloat) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 16),
            .foregroundColor: UIColor.black
        ]
        let string = NSAttributedString(string: title, attributes: attributes)
        string.draw(at: CGPoint(x: x, y: y))
        
        // Draw underline
        let lineY = y + 22
        let path = UIBezierPath()
        path.move(to: CGPoint(x: x, y: lineY))
        path.addLine(to: CGPoint(x: x + width, y: lineY))
        grayColor.setStroke()
        path.lineWidth = 2
        path.stroke()
        
        return 30
    }
    
    private static func drawMetricRowWithTarget(_ label: String, value: String, score: Int, target: String, x: CGFloat, y: CGFloat, width: CGFloat) -> CGFloat {
        // Color indicator
        let indicatorSize: CGFloat = 8
        let indicatorColor = colorForScore(score)
        let indicatorRect = CGRect(x: x, y: y + 3, width: indicatorSize, height: indicatorSize)
        indicatorColor.setFill()
        UIBezierPath(ovalIn: indicatorRect).fill()
        
        // Label
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.black
        ]
        let labelString = NSAttributedString(string: label, attributes: labelAttributes)
        labelString.draw(at: CGPoint(x: x + indicatorSize + 5, y: y))
        
        // Value
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 10),
            .foregroundColor: UIColor.black
        ]
        let valueString = NSAttributedString(string: value, attributes: valueAttributes)
        let valueSize = valueString.boundingRect(with: CGSize(width: 100, height: 20), options: .usesLineFragmentOrigin, context: nil)
        valueString.draw(at: CGPoint(x: x + width - valueSize.width, y: y))
        
        // Target value (if provided)
        if !target.isEmpty {
            let targetAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9),
                .foregroundColor: grayColor
            ]
            let targetString = NSAttributedString(string: target, attributes: targetAttributes)
            targetString.draw(at: CGPoint(x: x + indicatorSize + 5, y: y + 12))
            return 28
        }
        
        return 18
    }
    
    private static func drawTargetText(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.italicSystemFont(ofSize: 9),
            .foregroundColor: grayColor
        ]
        let string = NSAttributedString(string: text, attributes: attributes)
        let textRect = CGRect(x: x, y: y, width: width, height: 25)
        string.draw(in: textRect)
        return 20
    }
    
    private static func drawEnergyDistributionChart(distribution: EnergyDistribution?, x: CGFloat, y: CGFloat, width: CGFloat) -> CGFloat {
        guard let dist = distribution else {
            return drawNoDataMessage("Ei energiadataa", x: x, y: y, width: width)
        }
        
        var currentY = y
        
        // Chart title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 12),
            .foregroundColor: UIColor.black
        ]
        let titleString = NSAttributedString(string: "Energian jakautuminen vuorokauden aikana", attributes: titleAttributes)
        titleString.draw(at: CGPoint(x: x, y: currentY))
        currentY += 20
        
        // Calculate total energy for percentages
        let totalEnergy = dist.morning + dist.midday + dist.evening + dist.night
        guard totalEnergy > 0 else {
            return currentY + drawNoDataMessage("Ei energiadataa", x: x, y: currentY, width: width)
        }
        
        // Draw bars for each time period
        let barHeight: CGFloat = 16
        let barSpacing: CGFloat = 4
        let maxBarWidth = width - 80 // Leave space for labels
        
        let periods = [
            ("Aamu (03-09)", dist.morning, UIColor.orange),
            ("Päivä (09-15)", dist.midday, UIColor.blue),
            ("Ilta (15-21)", dist.evening, greenColor),
            ("Yö (21-03)", dist.night, UIColor.purple)
        ]
        
        for (label, energy, color) in periods {
            let percentage = energy / totalEnergy * 100
            let barWidth = maxBarWidth * (energy / totalEnergy)
            
            // Draw bar
            let barRect = CGRect(x: x, y: currentY, width: barWidth, height: barHeight)
            color.withAlphaComponent(0.7).setFill()
            UIBezierPath(rect: barRect).fill()
            
            // Draw label and percentage
            let labelText = "\(label): \(Int(percentage))%"
            let labelAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9),
                .foregroundColor: UIColor.black
            ]
            let labelString = NSAttributedString(string: labelText, attributes: labelAttributes)
            labelString.draw(at: CGPoint(x: x + barWidth + 10, y: currentY + 1))
            
            currentY += barHeight + barSpacing
        }
        
        return currentY - y + 8
    }
    
    private static func drawStepGoalAchievements(achievements: [Int: Int], x: CGFloat, y: CGFloat, width: CGFloat) -> CGFloat {
        var currentY = y
        
        // Title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.black
        ]
        let titleString = NSAttributedString(string: "Tavoitepäivät:", attributes: titleAttributes)
        titleString.draw(at: CGPoint(x: x, y: currentY))
        currentY += 15
        
        // Achievement rows
        let sortedGoals = achievements.keys.sorted()
        for goal in sortedGoals {
            let days = achievements[goal] ?? 0
            let achievementText = "\(goal): \(days) päivää"
            let score = days >= 10 ? 80 : (days >= 5 ? 65 : 30)
            
            // Small indicator and text
            let indicatorSize: CGFloat = 6
            let indicatorColor = colorForScore(score)
            let indicatorRect = CGRect(x: x, y: currentY + 2, width: indicatorSize, height: indicatorSize)
            indicatorColor.setFill()
            UIBezierPath(ovalIn: indicatorRect).fill()
            
            let textAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 9),
                .foregroundColor: UIColor.black
            ]
            let textString = NSAttributedString(string: achievementText, attributes: textAttributes)
            textString.draw(at: CGPoint(x: x + indicatorSize + 4, y: currentY))
            
            currentY += 12
        }
        
        return currentY - y
    }
    
    private static func drawMetricRow(_ label: String, value: String, score: Int, x: CGFloat, y: CGFloat, width: CGFloat) -> CGFloat {
        // Color indicator
        let indicatorSize: CGFloat = 8
        let indicatorColor = colorForScore(score)
        let indicatorRect = CGRect(x: x, y: y + 3, width: indicatorSize, height: indicatorSize)
        indicatorColor.setFill()
        UIBezierPath(ovalIn: indicatorRect).fill()
        
        // Label
        let labelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.black
        ]
        let labelString = NSAttributedString(string: label, attributes: labelAttributes)
        labelString.draw(at: CGPoint(x: x + indicatorSize + 5, y: y))
        
        // Value
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 10),
            .foregroundColor: UIColor.black
        ]
        let valueString = NSAttributedString(string: value, attributes: valueAttributes)
        let valueSize = valueString.boundingRect(with: CGSize(width: 100, height: 20), options: .usesLineFragmentOrigin, context: nil)
        valueString.draw(at: CGPoint(x: x + width - valueSize.width, y: y))
        
        return 18
    }
    
    private static func drawMacroPieChart(macros: MacrosPct, x: CGFloat, y: CGFloat, width: CGFloat) -> CGFloat {
        let chartSize: CGFloat = 65
        let centerX = x + width / 2
        let centerY = y + chartSize / 2
        let radius = chartSize / 2 - 8
        
        let total = macros.carbs + macros.protein + macros.fat
        guard total > 0 else {
            _ = drawNoDataMessage("Ei makrodataa", x: x, y: y, width: width)
            return chartSize
        }
        
        var startAngle: CGFloat = -CGFloat.pi / 2
        
        // Carbs (orange)
        let carbsAngle = CGFloat(macros.carbs / total) * 2 * CGFloat.pi
        drawPieSlice(center: CGPoint(x: centerX, y: centerY), radius: radius, startAngle: startAngle, endAngle: startAngle + carbsAngle, color: UIColor.orange)
        startAngle += carbsAngle
        
        // Protein (blue)
        let proteinAngle = CGFloat(macros.protein / total) * 2 * CGFloat.pi
        drawPieSlice(center: CGPoint(x: centerX, y: centerY), radius: radius, startAngle: startAngle, endAngle: startAngle + proteinAngle, color: UIColor.blue)
        startAngle += proteinAngle
        
        // Fat (green)
        let fatAngle = CGFloat(macros.fat / total) * 2 * CGFloat.pi
        drawPieSlice(center: CGPoint(x: centerX, y: centerY), radius: radius, startAngle: startAngle, endAngle: startAngle + fatAngle, color: greenColor)
        
        // Legend
        drawMacroLegend(macros: macros, x: x, y: y + chartSize + 4, width: width)
        
        return chartSize + 25
    }
    
    private static func drawPieSlice(center: CGPoint, radius: CGFloat, startAngle: CGFloat, endAngle: CGFloat, color: UIColor) {
        let path = UIBezierPath()
        path.move(to: center)
        path.addArc(withCenter: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: true)
        path.close()
        color.setFill()
        path.fill()
    }
    
    private static func drawMacroLegend(macros: MacrosPct, x: CGFloat, y: CGFloat, width: CGFloat) {
        let legendY = y
        let itemWidth = width / 3
        
        // Carbs
        drawLegendItem("H", color: UIColor.orange, percentage: macros.carbs, x: x, y: legendY, width: itemWidth)
        
        // Protein
        drawLegendItem("P", color: UIColor.blue, percentage: macros.protein, x: x + itemWidth, y: legendY, width: itemWidth)
        
        // Fat
        drawLegendItem("R", color: greenColor, percentage: macros.fat, x: x + 2 * itemWidth, y: legendY, width: itemWidth)
    }
    
    private static func drawLegendItem(_ label: String, color: UIColor, percentage: Double, x: CGFloat, y: CGFloat, width: CGFloat) {
        // Color square
        let squareSize: CGFloat = 7
        let squareRect = CGRect(x: x, y: y, width: squareSize, height: squareSize)
        color.setFill()
        UIBezierPath(rect: squareRect).fill()
        
        // Label and percentage
        let text = "\(label): \(Int(percentage * 100))%"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9),
            .foregroundColor: UIColor.black
        ]
        let string = NSAttributedString(string: text, attributes: attributes)
        string.draw(at: CGPoint(x: x + squareSize + 3, y: y - 1))
    }
    
    private static func drawMealInfo(_ title: String, score: Int, x: CGFloat, y: CGFloat, width: CGFloat) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 9),
            .foregroundColor: UIColor.black
        ]
        let text = "\(title): \(score)/100"
        let string = NSAttributedString(string: text, attributes: attributes)
        string.draw(at: CGPoint(x: x, y: y))
        return 12
    }
    
    private static func drawRecommendationText(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.italicSystemFont(ofSize: 9),
            .foregroundColor: grayColor
        ]
        let string = NSAttributedString(string: text, attributes: attributes)
        let textRect = CGRect(x: x, y: y, width: width, height: 18)
        string.draw(in: textRect)
        return 18
    }
    
    private static func drawAGPChart(report: ReportData, x: CGFloat, y: CGFloat, width: CGFloat, ctx: UIGraphicsPDFRendererContext) -> CGFloat {
        guard let agpData = report.agpData else {
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 12),
                .foregroundColor: UIColor.black
            ]
            let titleString = NSAttributedString(string: "Ambulatory Glucose Profile (AGP)", attributes: titleAttributes)
            titleString.draw(at: CGPoint(x: x, y: y))
            
            return drawNoDataMessage("Ei AGP-dataa", x: x, y: y + 20, width: width) + 20
        }
        
        let chartHeight: CGFloat = 120 // Reduced height for space saving
        let chartRect = CGRect(x: x, y: y + 20, width: width, height: chartHeight)
        
        // Chart title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 12),
            .foregroundColor: UIColor.black
        ]
        let titleString = NSAttributedString(string: "Ambulatory Glucose Profile (AGP)", attributes: titleAttributes)
        titleString.draw(at: CGPoint(x: x, y: y))
        
        // Draw chart background
        grayColor.withAlphaComponent(0.1).setFill()
        UIBezierPath(rect: chartRect).fill()
        
        // Chart border
        grayColor.setStroke()
        UIBezierPath(rect: chartRect).stroke()
        
        // Draw target range background (3.9-10.0 mmol/L)
        let targetMinY = chartRect.maxY - (3.9 / 15.0) * chartHeight
        let targetMaxY = chartRect.maxY - (10.0 / 15.0) * chartHeight
        let targetRect = CGRect(x: chartRect.minX, y: targetMaxY, width: chartRect.width, height: targetMinY - targetMaxY)
        greenColor.withAlphaComponent(0.1).setFill()
        UIBezierPath(rect: targetRect).fill()
        
        // Convert time points and glucose values to chart coordinates
        func chartX(for timePoint: Int) -> CGFloat {
            return chartRect.minX + CGFloat(timePoint) / 23.0 * chartRect.width
        }
        
        func chartY(for glucoseValue: Double) -> CGFloat {
            let clampedValue = max(0.0, min(15.0, glucoseValue)) // Clamp to 0-15 mmol/L
            return chartRect.maxY - (clampedValue / 15.0) * chartHeight
        }
        
        // Draw percentile bands
        if agpData.timePoints.count > 1 {
            // 10-90% band (lightest)
            drawPercentileBand(agpData.timePoints, agpData.percentile10, agpData.percentile90, 
                               chartX: chartX, chartY: chartY, color: grayColor.withAlphaComponent(0.2))
            
            // 25-75% band (darker)
            drawPercentileBand(agpData.timePoints, agpData.percentile25, agpData.percentile75, 
                               chartX: chartX, chartY: chartY, color: grayColor.withAlphaComponent(0.4))
            
            // Median line
            drawPercentileLine(agpData.timePoints, agpData.percentile50, 
                               chartX: chartX, chartY: chartY, color: UIColor.blue, lineWidth: 2)
        }
        
        // Draw Y-axis labels
        let yLabelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: grayColor
        ]
        for value in [0, 3, 6, 9, 12, 15] {
            let yPos = chartY(for: Double(value))
            let labelString = NSAttributedString(string: "\(value)", attributes: yLabelAttributes)
            labelString.draw(at: CGPoint(x: x - 20, y: yPos - 6))
        }
        
        // Draw X-axis labels
        let xLabelAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: grayColor
        ]
        for hour in [0, 6, 12, 18, 24] {
            let xPos = chartX(for: hour == 24 ? 23 : hour)
            let labelString = NSAttributedString(string: "\(hour):00", attributes: xLabelAttributes)
            let labelSize = labelString.boundingRect(with: CGSize(width: 50, height: 20), options: .usesLineFragmentOrigin, context: nil)
            labelString.draw(at: CGPoint(x: xPos - labelSize.width/2, y: chartRect.maxY + 5))
        }
        
        return chartHeight + 35
    }
    
    private static func drawPercentileBand(_ timePoints: [Int], _ lowerValues: [Double], _ upperValues: [Double], 
                                           chartX: (Int) -> CGFloat, chartY: (Double) -> CGFloat, color: UIColor) {
        guard timePoints.count == lowerValues.count && timePoints.count == upperValues.count else { return }
        
        let path = UIBezierPath()
        
        // Draw upper line
        if let firstPoint = timePoints.first {
            path.move(to: CGPoint(x: chartX(firstPoint), y: chartY(upperValues[0])))
        }
        for i in 1..<timePoints.count {
            path.addLine(to: CGPoint(x: chartX(timePoints[i]), y: chartY(upperValues[i])))
        }
        
        // Draw lower line in reverse
        for i in (0..<timePoints.count).reversed() {
            path.addLine(to: CGPoint(x: chartX(timePoints[i]), y: chartY(lowerValues[i])))
        }
        
        path.close()
        color.setFill()
        path.fill()
    }
    
    private static func drawPercentileLine(_ timePoints: [Int], _ values: [Double], 
                                           chartX: (Int) -> CGFloat, chartY: (Double) -> CGFloat, color: UIColor, lineWidth: CGFloat) {
        guard timePoints.count == values.count else { return }
        
        let path = UIBezierPath()
        
        if let firstPoint = timePoints.first {
            path.move(to: CGPoint(x: chartX(firstPoint), y: chartY(values[0])))
        }
        
        for i in 1..<timePoints.count {
            path.addLine(to: CGPoint(x: chartX(timePoints[i]), y: chartY(values[i])))
        }
        
        color.setStroke()
        path.lineWidth = lineWidth
        path.stroke()
    }
    
    private static func drawSimpleChart(title: String, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        // Draw chart background
        let chartRect = CGRect(x: x, y: y, width: width, height: height)
        grayColor.withAlphaComponent(0.2).setFill()
        UIBezierPath(rect: chartRect).fill()
        
        // Chart border
        grayColor.setStroke()
        UIBezierPath(rect: chartRect).stroke()
        
        // Simple trend line (placeholder)
        let path = UIBezierPath()
        path.move(to: CGPoint(x: x + 10, y: y + height - 20))
        path.addLine(to: CGPoint(x: x + width/3, y: y + height - 30))
        path.addLine(to: CGPoint(x: x + 2*width/3, y: y + height - 25))
        path.addLine(to: CGPoint(x: x + width - 10, y: y + height - 35))
        greenColor.setStroke()
        path.lineWidth = 2
        path.stroke()
        
        // Title
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .foregroundColor: UIColor.black
        ]
        let titleString = NSAttributedString(string: title, attributes: titleAttributes)
        titleString.draw(at: CGPoint(x: x + 5, y: y + 5))
    }
    
    private static func drawNoDataMessage(_ message: String, x: CGFloat, y: CGFloat, width: CGFloat) -> CGFloat {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.italicSystemFont(ofSize: 10),
            .foregroundColor: grayColor
        ]
        let string = NSAttributedString(string: message, attributes: attributes)
        string.draw(at: CGPoint(x: x, y: y))
        return 16
    }
    
    private static func colorForScore(_ score: Int) -> UIColor {
        switch score {
        case 80...100:
            return greenColor
        case 60...79:
            return yellowColor
        default:
            return redColor
        }
    }
}
