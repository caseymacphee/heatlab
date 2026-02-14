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
    @State private var totalSessionCount: Int = 0  // For differentiating empty vs zero state
    @State private var mostRecentSessionDate: Date? = nil  // For inactivity insight

    // Paywall state
    @State private var showingPaywall = false
    
    // Chart display state
    @State private var selectedPoint: TrendPoint?
    @State private var selectedPointPosition: CGPoint = .zero
    @State private var showZoneTrend = false
    
    private let calculator = AnalysisCalculator()
    private let trendCalculator = TrendCalculator()
    
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
        VStack(spacing: 0) {
            // MARK: - Period Picker (always at top)
            periodPickerSection
                .padding(.horizontal)
                .padding(.top)
            
            // MARK: - Filter Pills (always visible when filters active or data exists)
            if let result = analysisResult, (result.hasData || hasActiveFilters) {
                filterPillsSection
                    .padding(.horizontal)
                    .padding(.top, 20)
            }
            
            Group {
                if isLoading {
                    VStack {
                        Spacer()
                        ProgressView()
                        Text("Loading analysis...")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let result = analysisResult {
                    if result.hasData {
                        // MARK: - Normal State (sessions in current period/filters)
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                // MARK: - Summary Card (unified factual/AI summary + metrics)
                                SummaryCard(
                                    result: result,
                                    allSessions: sessions,
                                    isPro: subscriptionManager.isPro,
                                    lastSessionDate: mostRecentSessionDate,
                                    onUpgradeTap: { showingPaywall = true }
                                )

                                // MARK: - Trend Chart
                                trendChartSection(result: result)

                                // MARK: - Acclimation Signal
                                if let acclimation = result.acclimation {
                                    AcclimationCardView(signal: acclimation)
                                } else if let bucket = selectedTemperatureBucket {
                                    // Filtered by temp but not enough sessions in this bucket
                                    bucketAcclimationHint(bucket: bucket)
                                } else {
                                    // No filter - explain the baseline system
                                    baselineExplanationHint
                                }
                            }
                            .padding()
                            .padding(.bottom, 20)  // Extra padding to avoid tab bar clipping
                        }
                    } else if totalSessionCount > 0 {
                        // MARK: - Zero State (sessions exist but none match current period/filters)
                        ScrollView {
                            VStack(alignment: .leading, spacing: 20) {
                                // Summary card with inactivity insight + zeroed metrics
                                SummaryCard(
                                    result: result,
                                    allSessions: sessions,
                                    isPro: subscriptionManager.isPro,
                                    lastSessionDate: mostRecentSessionDate,
                                    onUpgradeTap: { showingPaywall = true }
                                )

                                // Empty trend chart section (shows "No Data for Period")
                                trendChartSection(result: result)
                            }
                            .padding()
                            .padding(.bottom, 20)
                        }
                    } else {
                        // MARK: - Empty State (no sessions ever)
                        HLEmptyStateView(
                            systemImage: SFSymbol.mindAndBody,
                            title: "No Sessions Found",
                            description: emptyStateDescription
                        )
                    }
                }
            }
        }
        .background(Color.hlBackground)
        .navigationTitle("Analysis")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
        .onChange(of: selectedPeriod) { _, _ in
            // Period change requires re-fetching data (different date cutoffs)
            Task {
                await loadData()
            }
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
            // Header with title and chart mode toggle
            HStack(alignment: .firstTextBaseline) {
                Text(showZoneTrend ? "Heart Rate Zones" : "Avg. Heart Rate")
                    .font(.headline)
                Spacer()

                // Single toggle: switches between HR trend and zone distribution
                if settings.userAge != nil {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showZoneTrend.toggle()
                        }
                    } label: {
                        Image(systemName: showZoneTrend
                              ? "chart.line.uptrend.xyaxis.circle"
                              : "chart.bar")
                            .font(.title3)
                            .foregroundStyle(Color.hlAccent)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(showZoneTrend ? "Show trend" : "Show zones")
                    .accessibilityHint("Double tap to switch chart view")
                }
            }

            if showZoneTrend {
                // Zone trend chart (stacked bars)
                let zoneSessions = sessions.filter { session in
                    result.trendPoints.contains { $0.date == session.session.startDate }
                }.filter { $0.zoneDistribution != nil }

                if !zoneSessions.isEmpty {
                    ZoneTrendChartView(sessions: zoneSessions)
                }
            } else if result.trendPoints.isEmpty {
                ContentUnavailableView(
                    "No Data for Period",
                    systemImage: SFSymbol.mindAndBody,
                    description: Text("Complete sessions \(periodDescription) to see trends")
                )
                .frame(height: 200)
            } else {
                let ewmaPoints = trendCalculator.calculateEWMA(points: result.trendPoints, period: result.filters.period)
                
                Chart {
                    // EWMA trend line (behind points)
                    if !ewmaPoints.isEmpty {
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
                .chartYAxisLabel("BPM")
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
                
                // Compact temperature color legend
                HStack(spacing: 12) {
                    ForEach(TemperatureBucket.allCases, id: \.self) { bucket in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(tempLegendColor(bucket))
                                .frame(width: 6, height: 6)
                            Text(tempLegendLabel(bucket))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .heatLabCard()
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
    
    
    // MARK: - Empty State Description
    
    private var emptyStateDescription: String {
        var parts: [String] = []
        
        if let bucket = selectedTemperatureBucket {
            parts.append("for \(bucket.displayName(for: settings.temperatureUnit))")
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
    
    private var baselineExplanationHint: some View {
        HStack(spacing: 10) {
            Image(systemName: SFSymbol.thermometer)
                .foregroundStyle(Color.hlAccent)

            VStack(alignment: .leading, spacing: 2) {
                Text("Temperature Baselines")
                    .font(.subheadline.bold())
                Text("HeatLab tracks your heart rate baseline for each temperature range separately. Filter by temperature to see acclimation progress.")
                    .font(.caption)
                    .foregroundStyle(Color.hlMuted)
            }
        }
        .heatLabHintCard(color: Color.hlAccent)
    }

    private func bucketAcclimationHint(bucket: TemperatureBucket) -> some View {
        HStack(spacing: 10) {
            Image(systemName: SFSymbol.thermometer)
                .foregroundStyle(Color.hlAccent)

            VStack(alignment: .leading, spacing: 2) {
                Text("Building \(bucket.displayName(for: settings.temperatureUnit)) Baseline")
                    .font(.subheadline.bold())
                Text("Complete more sessions in this range to track acclimation progress.")
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

    private func tempLegendColor(_ bucket: TemperatureBucket) -> Color {
        switch bucket {
        case .unheated: return Color.secondary
        case .warm: return Color.HeatLab.tempWarm
        case .hot: return Color.HeatLab.tempHot
        case .veryHot: return Color.HeatLab.tempVeryHot
        case .hottest: return Color.HeatLab.tempExtreme
        }
    }

    private func tempLegendLabel(_ bucket: TemperatureBucket) -> String {
        switch bucket {
        case .unheated: return "None"
        case .warm: return "Warm"
        case .hot: return "Hot"
        case .veryHot: return "Very Hot"
        case .hottest: return "Hottest"
        }
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

        // Fetch total session count first (lightweight, no HealthKit) for empty vs zero state
        totalSessionCount = (try? repo.fetchTotalSessionCount()) ?? 0
        if totalSessionCount > 0 {
            mostRecentSessionDate = try? repo.fetchMostRecentSessionDate()
        } else {
            mostRecentSessionDate = nil
        }

        // Fetch sessions based on selected period - avoid loading entire history
        // Each period needs current + previous for comparison
        let cutoffDate = periodCutoffDate(for: selectedPeriod)
        sessions = (try? await repo.fetchSessionsWithStats(from: cutoffDate, maxHR: settings.estimatedMaxHR)) ?? []

        // DEBUG: Check session data
        print("📊 AnalysisView - Total sessions: \(totalSessionCount)")
        print("📊 AnalysisView - Sessions (period: \(selectedPeriod.rawValue)): \(sessions.count)")
        print("📊 AnalysisView - Sessions with HR: \(sessions.filter { $0.stats.averageHR > 0 }.count)")

        updateAnalysis()
        isLoading = false
    }

    /// Calculate cutoff date for fetching - needs 2x period for comparison
    private func periodCutoffDate(for period: AnalysisPeriod) -> Date? {
        let calendar = Calendar.current
        let now = Date()

        switch period {
        case .week:
            // Week view: need 14 days (current + previous week)
            return calendar.date(byAdding: .day, value: -14, to: now)
        case .month:
            // Month view: need 2 months
            return calendar.date(byAdding: .month, value: -2, to: now)
        case .threeMonth:
            // 3-month view: need 6 months
            return calendar.date(byAdding: .month, value: -6, to: now)
        case .year:
            // Year view: need 2 years (or unlimited for pro)
            return subscriptionManager.isPro ? nil : calendar.date(byAdding: .year, value: -2, to: now)
        }
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
        .frame(width: 180)
        .heatLabTooltip()
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


#Preview {
    NavigationStack {
        AnalysisView(resetTrigger: UUID())
    }
    .modelContainer(for: WorkoutSession.self, inMemory: true)
    .environment(UserSettings())
    .environment(SubscriptionManager())
    .environmentObject(WatchConnectivityReceiver.shared)
}
