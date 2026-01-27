//
//  AnalysisView.swift
//  heatlab
//
//  Multi-dimensional analysis with period comparisons and AI insights
//

import SwiftUI
import SwiftData
import Charts

struct AnalysisView: View {
    @Environment(\.modelContext) var modelContext
    @Environment(UserSettings.self) var settings
    @Environment(SubscriptionManager.self) var subscriptionManager
    @EnvironmentObject var wcReceiver: WatchConnectivityReceiver
    
    // Reset trigger from parent to clear filters on tab switch
    var resetTrigger: UUID = UUID()
    
    // Filter state
    @State private var selectedPeriod: AnalysisPeriod = .week
    @State private var selectedTemperatureBucket: TemperatureBucket? = nil
    @State private var selectedClassType: UUID? = nil
    
    // Data state
    @State private var sessions: [SessionWithStats] = []
    @State private var analysisResult: AnalysisResult?
    @State private var isLoading = true
    
    // AI insight state
    @State private var aiInsight: String?
    @State private var isGeneratingInsight = false
    @State private var insightGenerationTask: Task<Void, Never>?
    
    // Paywall state
    @State private var showingPaywall = false
    
    // Chart display state
    @State private var showTrendLine: Bool = true
    @State private var selectedPoint: TrendPoint?
    @State private var selectedPointPosition: CGPoint = .zero
    @State private var showingLegend = false
    
    private let calculator = AnalysisCalculator()
    private let trendCalculator = TrendCalculator()
    private let insightGenerator = AnalysisInsightGenerator()
    
    private var filters: AnalysisFilters {
        AnalysisFilters(
            temperatureBucket: selectedTemperatureBucket,
            sessionTypeId: selectedClassType,
            period: selectedPeriod
        )
    }
    
    private var hasActiveFilters: Bool {
        selectedTemperatureBucket != nil || selectedClassType != nil
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // MARK: - Period Picker (keep at top)
                periodPickerSection

                if isLoading {
                    loadingView
                } else if let result = analysisResult {
                    // MARK: - Filter Pills (always visible when filters active or data exists)
                    // Show pills when there's data OR when filters are active (so user can clear them)
                    if result.hasData || hasActiveFilters {
                        filterPillsSection
                    }
                    
                    if result.hasData {
                        // MARK: - Summary Card (unified factual/AI summary + metrics)
                        SummaryCard(
                            result: result,
                            isPro: subscriptionManager.isPro,
                            aiInsight: aiInsight,
                            isGeneratingInsight: isGeneratingInsight,
                            onUpgradeTap: { showingPaywall = true }
                        )

                        // MARK: - Trend Chart
                        trendChartSection(result: result)

                        // MARK: - Acclimation Signal
                        if let acclimation = result.acclimation {
                            AcclimationCardView(signal: acclimation)
                        } else if result.comparison.current.sessionCount < 5 {
                            // Hint about needing more sessions for acclimation
                            acclimationHint(sessionsNeeded: 5 - result.comparison.current.sessionCount)
                        }
                    } else {
                        // MARK: - Empty State
                        emptyStateView
                    }
                }
            }
            .padding()
            .padding(.bottom, 20)  // Extra padding to avoid tab bar clipping
        }
        .background(Color.hlBackground)
        .navigationTitle("Analysis")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
        .onChange(of: selectedPeriod) { _, _ in
            updateAnalysis()
        }
        .onChange(of: selectedTemperatureBucket) { _, _ in
            updateAnalysis()
        }
        .onChange(of: selectedClassType) { _, _ in
            updateAnalysis()
        }
        .onChange(of: wcReceiver.lastReceivedDate) {
            Task {
                await loadData()
            }
        }
        .onChange(of: resetTrigger) { _, _ in
            resetFilters()
        }
        .refreshable {
            await loadData()
        }
    }
    
    private func resetFilters() {
        selectedPeriod = .week
        selectedTemperatureBucket = nil
        selectedClassType = nil
        updateAnalysis()
    }
    
    // MARK: - Period Picker Section

    private var periodPickerSection: some View {
        HStack(spacing: 6) {
            ForEach(AnalysisPeriod.allCases) { period in
                PeriodButton(
                    period: period,
                    isSelected: selectedPeriod == period,
                    isLocked: period.requiresPro && !subscriptionManager.isPro
                ) {
                    if period.requiresPro && !subscriptionManager.isPro {
                        showingPaywall = true
                    } else {
                        selectedPeriod = period
                    }
                }
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: HLRadius.chip + 4)
                .fill(Color.hlSurface2)
        )
        .sheet(isPresented: $showingPaywall) {
            PaywallView()
        }
    }

    // MARK: - Filter Pills Section

    private var filterPillsSection: some View {
        FilterPillRow(
            selectedTemperatureBucket: $selectedTemperatureBucket,
            selectedClassType: $selectedClassType
        )
    }
    
    private var selectedClassTypeName: String? {
        guard let id = selectedClassType else { return nil }
        return settings.sessionTypeName(for: id)
    }
    
    // MARK: - Trend Chart

    private func trendChartSection(result: AnalysisResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with title and trend line icon toggle
            HStack(alignment: .firstTextBaseline) {
                Text("Heart Rate")
                    .font(.headline)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showTrendLine.toggle()
                    }
                } label: {
                    Image(systemName: showTrendLine ? "chart.line.uptrend.xyaxis.circle.fill" : "chart.line.uptrend.xyaxis.circle")
                        .font(.title3)
                        .foregroundStyle(showTrendLine ? Color.hlAccent : Color.hlMuted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Trend line")
                .accessibilityValue(showTrendLine ? "On" : "Off")
                .accessibilityHint("Double tap to toggle trend line visibility")
            }

            if result.trendPoints.isEmpty {
                ContentUnavailableView(
                    "No Data for Period",
                    systemImage: "chart.line.downtrend.xyaxis",
                    description: Text("Complete sessions \(periodDescription) to see trends")
                )
                .frame(height: 200)
            } else {
                let ewmaPoints = trendCalculator.calculateEWMA(points: result.trendPoints, period: result.filters.period)
                
                Chart {
                    // EWMA trend line (behind points, only when toggled on and enough data)
                    if showTrendLine && !ewmaPoints.isEmpty {
                        ForEach(ewmaPoints) { point in
                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("HR", point.value)
                            )
                            .foregroundStyle(Color.secondary.opacity(0.5))
                            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                            .interpolationMethod(.catmullRom)
                        }
                    }
                    
                    // Temperature-colored points (always shown)
                    ForEach(result.trendPoints) { point in
                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("HR", point.value)
                        )
                        .foregroundStyle(pointColor(for: point.temperature))
                        .symbolSize(60)
                    }
                }
                .chartYAxisLabel("Avg HR")
                .chartYScale(domain: yAxisDomain(for: result.trendPoints))
                .chartXScale(domain: xAxisDomain(for: result.filters.period))
                .chartXAxis {
                    AxisMarks(values: xAxisValues(for: result.filters.period)) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: xAxisLabelFormat(for: result.filters.period))
                    }
                }
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        ZStack {
                            // Tap detection layer
                            Rectangle()
                                .fill(.clear)
                                .contentShape(Rectangle())
                                .onTapGesture { location in
                                    if let point = findNearestPoint(
                                        at: location,
                                        in: result.trendPoints,
                                        proxy: proxy,
                                        geometry: geo
                                    ) {
                                        // Calculate point position for tooltip anchoring
                                        if let position = pointPosition(
                                            for: point,
                                            proxy: proxy,
                                            geometry: geo
                                        ) {
                                            selectedPoint = point
                                            selectedPointPosition = position
                                        }
                                    } else {
                                        // Tap on empty space dismisses tooltip
                                        selectedPoint = nil
                                    }
                                }
                            
                            // Selection ring highlight (in overlay to avoid chart re-render)
                            if selectedPoint != nil {
                                Circle()
                                    .stroke(Color.primary.opacity(0.4), lineWidth: 2)
                                    .frame(width: 14, height: 14)
                                    .position(selectedPointPosition)
                            }
                            
                            // Tooltip callout anchored near point
                            if let point = selectedPoint {
                                ChartCalloutView(
                                    point: point,
                                    classTypeName: settings.sessionTypeName(for: point.sessionTypeId),
                                    temperatureUnit: settings.temperatureUnit
                                )
                                .position(calloutPosition(
                                    pointPosition: selectedPointPosition,
                                    in: geo.size
                                ))
                            }
                        }
                    }
                }
                .animation(nil, value: selectedPoint?.id)
                .frame(height: 220)
                .padding(.bottom, 4)
                
                // Temperature legend button
                HStack {
                    Spacer()
                    Button { showingLegend = true } label: {
                        Label("Temp Colors", systemImage: SFSymbol.thermometer)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .heatLabCard()
        .sheet(isPresented: $showingLegend) {
            TemperatureLegendSheet()
                .presentationDetents([.medium])
        }
    }
    
    /// Find the nearest TrendPoint to a tap location
    private func findNearestPoint(
        at location: CGPoint,
        in points: [TrendPoint],
        proxy: ChartProxy,
        geometry: GeometryProxy
    ) -> TrendPoint? {
        let plotOrigin = geometry[proxy.plotFrame!].origin
        let adjustedLocation = CGPoint(
            x: location.x - plotOrigin.x,
            y: location.y - plotOrigin.y
        )
        
        guard let tappedDate: Date = proxy.value(atX: adjustedLocation.x) else {
            return nil
        }
        
        // Find closest point by date
        var closestPoint: TrendPoint?
        var closestDistance: TimeInterval = .infinity
        
        for point in points {
            let distance = abs(point.date.timeIntervalSince(tappedDate))
            if distance < closestDistance {
                closestDistance = distance
                closestPoint = point
            }
        }
        
        // Only select if within reasonable tap distance (half a day for week view, more for longer views)
        let maxDistance: TimeInterval = 12 * 60 * 60 // 12 hours
        if closestDistance < maxDistance {
            return closestPoint
        }
        
        return nil
    }
    
    /// Get the screen position of a TrendPoint within the chart
    private func pointPosition(
        for point: TrendPoint,
        proxy: ChartProxy,
        geometry: GeometryProxy
    ) -> CGPoint? {
        guard let plotFrame = proxy.plotFrame else { return nil }
        let plotOrigin = geometry[plotFrame].origin
        
        guard let xPos = proxy.position(forX: point.date),
              let yPos = proxy.position(forY: point.value) else {
            return nil
        }
        
        return CGPoint(
            x: plotOrigin.x + xPos,
            y: plotOrigin.y + yPos
        )
    }
    
    /// Calculate the callout position, keeping it within bounds and offset from the point
    private func calloutPosition(pointPosition: CGPoint, in size: CGSize) -> CGPoint {
        let calloutWidth: CGFloat = 180
        let calloutHeight: CGFloat = 120
        let verticalOffset: CGFloat = 50  // Distance above the point
        let edgePadding: CGFloat = 8
        
        // Default: position above and centered on the point
        var x = pointPosition.x
        var y = pointPosition.y - verticalOffset
        
        // Keep within horizontal bounds
        let halfWidth = calloutWidth / 2
        if x - halfWidth < edgePadding {
            x = halfWidth + edgePadding
        } else if x + halfWidth > size.width - edgePadding {
            x = size.width - halfWidth - edgePadding
        }
        
        // If too close to top, position below the point instead
        if y - calloutHeight / 2 < edgePadding {
            y = pointPosition.y + verticalOffset
        }
        
        // Final bounds check for vertical
        let halfHeight = calloutHeight / 2
        y = max(halfHeight + edgePadding, min(y, size.height - halfHeight - edgePadding))
        
        return CGPoint(x: x, y: y)
    }

    private var periodDescription: String {
        switch selectedPeriod {
        case .week: return "this week"
        case .month: return "this month"
        case .threeMonth: return "the past 3 months"
        case .year: return "this year"
        }
    }
    
    
    // MARK: - Loading & Empty States
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Loading analysis...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 300)
    }
    
    private var emptyStateView: some View {
        ContentUnavailableView(
            "No Sessions Found",
            systemImage: SFSymbol.mindAndBody,
            description: Text(emptyStateDescription)
        )
        .frame(height: 250)
    }
    
    private var emptyStateDescription: String {
        var parts: [String] = []
        
        if let bucket = selectedTemperatureBucket {
            parts.append("for \(bucket.displayName)")
        }
        if let typeName = selectedClassTypeName {
            parts.append("for \(typeName)")
        }
        parts.append(periodDescription)
        
        if parts.isEmpty {
            return "Complete some sessions to see analysis"
        }
        return "No sessions found \(parts.joined(separator: " "))"
    }
    
    // MARK: - Context Hints
    
    private func acclimationHint(sessionsNeeded: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: SFSymbol.thermometer)
                .foregroundStyle(Color.hlAccent)

            VStack(alignment: .leading, spacing: 2) {
                Text("Building Your Heat Baseline")
                    .font(.subheadline.bold())
                Text("\(sessionsNeeded) more session\(sessionsNeeded == 1 ? "" : "s") needed to track heat acclimation progress")
                    .font(.caption)
                    .foregroundStyle(Color.hlMuted)
            }
        }
        .heatLabHintCard(color: Color.hlAccent)
    }
    
    // MARK: - Chart Helpers

    private func yAxisDomain(for points: [TrendPoint]) -> ClosedRange<Double> {
        guard !points.isEmpty else { return 100...180 }
        
        let values = points.map { $0.value }
        let actualMin = values.min() ?? 100
        let actualMax = values.max() ?? 180
        
        let padding = 10.0
        // Don't hardcode a minimum - use the actual minimum from data with padding
        let minVal = max(0, (actualMin - padding).rounded(.down))
        let maxVal = (actualMax + padding).rounded(.up)
        
        return minVal...maxVal
    }

    private func pointColor(for temperature: Int) -> Color {
        Color.HeatLab.temperature(fahrenheit: temperature)
    }
    
    private func formattedTemp(_ fahrenheit: Int) -> String {
        let temp = Temperature(fahrenheit: fahrenheit)
        let value = temp.value(for: settings.temperatureUnit)
        return "\(value)\(settings.temperatureUnit.rawValue)"
    }
    
    // MARK: - X-Axis Helpers
    
    private func xAxisDomain(for period: AnalysisPeriod) -> ClosedRange<Date> {
        let (start, end) = calculator.periodDateRange(for: period, offset: 0)
        return start...end
    }
    
    private func xAxisValues(for period: AnalysisPeriod) -> [Date] {
        let (start, end) = calculator.periodDateRange(for: period, offset: 0)
        let calendar = Calendar.current
        
        switch period {
        case .week:
            // Show each day of the week
            var dates: [Date] = []
            var currentDate = start
            while currentDate <= end {
                dates.append(currentDate)
                guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else { break }
                currentDate = nextDate
            }
            return dates
            
        case .month:
            // Show approximately weekly intervals (every 7 days)
            var dates: [Date] = [start]
            var currentDate = start
            while currentDate < end {
                guard let nextDate = calendar.date(byAdding: .day, value: 7, to: currentDate) else { break }
                if nextDate <= end {
                    dates.append(nextDate)
                }
                currentDate = nextDate
            }
            if dates.last != end {
                dates.append(end)
            }
            return dates
            
        case .threeMonth:
            // Show bi-weekly intervals for 3-month view
            var dates: [Date] = [start]
            var currentDate = start
            while currentDate < end {
                guard let nextDate = calendar.date(byAdding: .day, value: 14, to: currentDate) else { break }
                if nextDate <= end {
                    dates.append(nextDate)
                }
                currentDate = nextDate
            }
            if dates.last != end {
                dates.append(end)
            }
            return dates
            
        case .year:
            // Show monthly intervals
            var dates: [Date] = [start]
            var currentDate = start
            while currentDate < end {
                guard let nextDate = calendar.date(byAdding: .month, value: 1, to: currentDate) else { break }
                if nextDate <= end {
                    dates.append(nextDate)
                }
                currentDate = nextDate
            }
            if dates.last != end {
                dates.append(end)
            }
            return dates
        }
    }
    
    private func xAxisLabelFormat(for period: AnalysisPeriod) -> Date.FormatStyle {
        switch period {
        case .week:
            // Format as M/d (e.g., "11/2", "11/3")
            return Date.FormatStyle()
                .month(.twoDigits)
                .day(.twoDigits)
            
        case .month, .threeMonth:
            // Format as M/d for month and 3-month views
            return Date.FormatStyle()
                .month(.twoDigits)
                .day(.twoDigits)
            
        case .year:
            // Format as MMM for year view (e.g., "Jan", "Feb")
            return Date.FormatStyle()
                .month(.abbreviated)
        }
    }
    
    // MARK: - Data Loading
    
    private func loadData() async {
        isLoading = true
        let repo = SessionRepository(modelContext: modelContext)
        
        // Fetch all sessions (analysis uses full history for trends)
        sessions = (try? await repo.fetchAllSessionsWithStats()) ?? []

        // DEBUG: Check session data
        print("📊 AnalysisView - Total sessions: \(sessions.count)")
        print("📊 AnalysisView - Sessions with HR: \(sessions.filter { $0.stats.averageHR > 0 }.count)")

        updateAnalysis()
        isLoading = false
    }
    
    private func updateAnalysis() {
        analysisResult = calculator.analyze(
            sessions: sessions,
            filters: filters,
            isPro: subscriptionManager.isPro
        )

        // DEBUG: Check analysis results
        if let result = analysisResult {
            print("📊 AnalysisView - After filtering: \(result.comparison.current.sessionCount) sessions")
            print("📊 AnalysisView - hasData: \(result.hasData)")
            print("📊 AnalysisView - hasComparison: \(result.hasComparison)")
        }

        // Clear existing insight and trigger new generation with debounce
        aiInsight = nil
        if subscriptionManager.isPro {
            scheduleInsightGeneration()
        }
    }
    
    private func scheduleInsightGeneration() {
        // Don't generate if AI not available
        guard AnalysisInsightGenerator.isAvailable else { return }
        
        // Cancel any pending insight generation
        insightGenerationTask?.cancel()
        
        // Debounce: wait a short moment before generating to avoid rapid requests
        insightGenerationTask = Task {
            // Small delay to debounce rapid filter changes
            try? await Task.sleep(for: .milliseconds(300))
            
            guard !Task.isCancelled else { return }
            
            await generateInsight()
        }
    }
    
    @MainActor
    private func generateInsight() async {
        guard let result = analysisResult, result.hasData else {
            aiInsight = nil
            return
        }
        
        isGeneratingInsight = true
        
        do {
            let insight = try await insightGenerator.generateInsight(
                for: result,
                temperatureName: selectedTemperatureBucket?.displayName,
                classTypeName: selectedClassTypeName
            )
            
            // Only update if we haven't been cancelled (filters didn't change)
            if !Task.isCancelled {
                withAnimation {
                    aiInsight = insight
                }
            }
        } catch {
            // Silently fail - insight is optional enhancement
            print("Failed to generate insight: \(error)")
        }
        
        isGeneratingInsight = false
    }
}

// MARK: - Period Button

private struct PeriodButton: View {
    let period: AnalysisPeriod
    let isSelected: Bool
    let isLocked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(period.rawValue)
                    .font(.subheadline.weight(isSelected ? .semibold : .regular))

                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                }
            }
            .foregroundStyle(isSelected ? Color.hlText : (isLocked ? Color.hlMuted : Color.hlText))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: HLRadius.chip)
                    .fill(isSelected ? Color.hlSurface : Color.hlSurface2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Chart Tooltip View

/// Compact callout view that appears inside the chart area near the selected point
private struct ChartCalloutView: View {
    let point: TrendPoint
    let classTypeName: String?
    let temperatureUnit: TemperatureUnit
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Date header
            Text(point.date, format: .dateTime.weekday(.abbreviated).month(.abbreviated).day())
                .font(.caption.bold())
                .foregroundStyle(.primary)
            
            // Compact metrics
            HStack(spacing: 12) {
                // Heart Rate
                HStack(spacing: 3) {
                    Image(systemName: SFSymbol.heartFill)
                        .font(.caption2)
                        .foregroundStyle(Color.HeatLab.heartRate)
                    Text("\(Int(point.value))")
                        .font(.caption.monospacedDigit())
                }
                
                // Duration
                HStack(spacing: 3) {
                    Image(systemName: SFSymbol.clock)
                        .font(.caption2)
                        .foregroundStyle(Color.HeatLab.duration)
                    Text(formattedDuration)
                        .font(.caption.monospacedDigit())
                }
                
                // Temperature
                HStack(spacing: 3) {
                    Image(systemName: SFSymbol.thermometer)
                        .font(.caption2)
                        .foregroundStyle(Color.HeatLab.temperature(fahrenheit: point.temperature))
                    Text(temperatureText)
                        .font(.caption.monospacedDigit())
                }
            }
            .foregroundStyle(.secondary)
            
            // Class type (if available)
            if let className = classTypeName {
                Text(className)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(10)
        .frame(width: 180)
        .background {
            RoundedRectangle(cornerRadius: HeatLabRadius.sm)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
    }
    
    private var formattedDuration: String {
        let minutes = Int(point.duration / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            return "\(hours)h\(remainingMinutes)m"
        }
        return "\(minutes)m"
    }
    
    private var temperatureText: String {
        if point.temperature == 0 {
            return "—"
        }
        let temp = Temperature(fahrenheit: point.temperature)
        let value = temp.value(for: temperatureUnit)
        return "\(value)°"
    }
}

// MARK: - Temperature Legend Sheet

private struct TemperatureLegendSheet: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text("Point colors indicate the room temperature during your session.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
                
                VStack(spacing: 0) {
                    ForEach(TemperatureBucket.allCases, id: \.self) { bucket in
                        HStack(spacing: 12) {
                            Circle()
                                .fill(colorForBucket(bucket))
                                .frame(width: 16, height: 16)
                            
                            Text(bucket.displayName)
                                .font(.body)
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        
                        if bucket != TemperatureBucket.allCases.last {
                            Divider()
                                .padding(.leading, 40)
                        }
                    }
                }
                .background(Color.hlSurface)
                .clipShape(RoundedRectangle(cornerRadius: HLRadius.card))
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top)
            .navigationTitle("Temperature Colors")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
    
    private func colorForBucket(_ bucket: TemperatureBucket) -> Color {
        switch bucket {
        case .unheated: return Color.secondary
        case .warm: return Color.HeatLab.tempWarm
        case .hot: return Color.HeatLab.tempHot
        case .veryHot: return Color.HeatLab.tempVeryHot
        case .extreme: return Color.HeatLab.tempExtreme
        }
    }
}

#Preview {
    NavigationStack {
        AnalysisView(resetTrigger: UUID())
    }
    .modelContainer(for: WorkoutSession.self, inMemory: true)
    .environment(UserSettings())
    .environment(SubscriptionManager())
    .environmentObject(WatchConnectivityReceiver.shared)
}
