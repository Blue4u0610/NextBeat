import SwiftUI
import WidgetKit

struct NextBeatEntry: TimelineEntry {
    let date: Date
    let snapshot: DaySnapshot
    let week: WeekPlan?
    let reflection: ReflectionSettings
    let error: String?
}

struct NextBeatProvider: TimelineProvider {
    func placeholder(in context: Context) -> NextBeatEntry {
        NextBeatEntry(date: PreviewFixtures.time(9, 45, day: 7),
                     snapshot: PlanEngine.snapshot(for: PreviewFixtures.denseWeek, at: PreviewFixtures.time(9, 45, day: 7)),
                     week: PreviewFixtures.denseWeek,
                     reflection: .defaultValue,
                     error: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (NextBeatEntry) -> Void) {
        if context.isPreview {
            completion(placeholder(in: context))
        } else {
            completion(entry(at: .now))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<NextBeatEntry>) -> Void) {
        let now = Date.now
        do {
            let plans = try PlanRepository.appGroup().load()
            let reflection = try ReflectionRepository.appGroup().load()
            // WidgetKit archives the entire seven-column view for every entry. A full
            // week of dense tasks can exceed its archive allowance. Include a 12-hour
            // buffer beyond the requested refresh, while bounding unusually busy days.
            let requestedRefresh = now.addingTimeInterval(24 * 60 * 60)
            let horizon = now.addingTimeInterval(36 * 60 * 60)
            let candidateDates = PlanEngine.timelineDates(in: plans, from: now, through: horizon)
            let dates = Array(candidateDates.prefix(36))
            let refresh: Date
            if candidateDates.count > dates.count {
                // Leave eight already-rendered transitions while a new timeline is requested.
                refresh = min(requestedRefresh, dates[dates.count - 8])
            } else {
                refresh = requestedRefresh
            }
            let entries = dates.map { date in
                NextBeatEntry(date: date,
                              snapshot: PlanEngine.snapshot(in: plans, at: date),
                              week: PlanEngine.activePlan(in: plans, at: date),
                              reflection: reflection,
                              error: nil)
            }
            // WidgetKit chooses when to display entries. Reload requests after edits may also be deferred by iOS.
            completion(Timeline(entries: entries, policy: .after(refresh)))
        } catch {
            completion(Timeline(entries: [NextBeatEntry(date: now, snapshot: .noPlan, week: nil,
                                                        reflection: .defaultValue, error: error.localizedDescription)],
                                policy: .after(now.addingTimeInterval(15 * 60))))
        }
    }

    private func entry(at date: Date) -> NextBeatEntry {
        do {
            let plans = try PlanRepository.appGroup().load()
            let reflection = try ReflectionRepository.appGroup().load()
            return NextBeatEntry(date: date, snapshot: PlanEngine.snapshot(in: plans, at: date),
                                 week: PlanEngine.activePlan(in: plans, at: date),
                                 reflection: reflection, error: nil)
        } catch {
            return NextBeatEntry(date: date, snapshot: .noPlan, week: nil,
                                 reflection: .defaultValue, error: error.localizedDescription)
        }
    }
}

struct NextBeatWidgetEntryView: View {
    let entry: NextBeatEntry
    var familyOverride: WidgetFamily? = nil
    @Environment(\.widgetFamily) private var environmentFamily
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    @ScaledMetric(relativeTo: .caption2) private var scaledGridTime: CGFloat = 7.8
    @ScaledMetric(relativeTo: .caption) private var scaledGridTitle: CGFloat = 9.3
    @ScaledMetric(relativeTo: .caption2) private var scaledWeekday: CGFloat = 14
    @ScaledMetric(relativeTo: .caption2) private var scaledDayNumber: CGFloat = 9
    @ScaledMetric(relativeTo: .caption2) private var scaledQuoteHeight: CGFloat = 22
    @ScaledMetric(relativeTo: .caption) private var scaledHeadingHeight: CGFloat = 25
    @ScaledMetric(relativeTo: .body) private var scaledFocusHeight: CGFloat = 96

    // Seven columns leave only about 45 pt per cell. Stack the two times rather than shrinking a range.
    private var gridTimeSize: CGFloat { min(scaledGridTime, 9) }
    private var gridEndTimeSize: CGFloat { max(7, gridTimeSize - 0.5) }
    private var gridTitleSize: CGFloat { min(scaledGridTitle, 15) }

    private var paper: Color {
        colorScheme == .dark ? Color(red: 0.125, green: 0.13, blue: 0.14) : Color(red: 0.969, green: 0.949, blue: 0.918)
    }
    private var surface: Color {
        colorScheme == .dark ? Color(red: 0.16, green: 0.165, blue: 0.18) : Color(red: 1, green: 0.988, blue: 0.969)
    }
    private var ink: Color {
        colorScheme == .dark ? Color(red: 0.969, green: 0.949, blue: 0.918) : Color(red: 0.145, green: 0.149, blue: 0.161)
    }
    private var mutedInk: Color {
        colorScheme == .dark ? Color(red: 0.72, green: 0.7, blue: 0.67) : Color(red: 0.40, green: 0.41, blue: 0.42)
    }
    private var rule: Color {
        colorScheme == .dark ? Color(red: 0.26, green: 0.26, blue: 0.28) : Color(red: 0.86, green: 0.84, blue: 0.81)
    }
    private var accent: Color {
        colorScheme == .dark ? Color(red: 1, green: 0.5, blue: 0.42) : Color(red: 0.67, green: 0.20, blue: 0.13)
    }
    private var upcomingAccent: Color {
        colorScheme == .dark ? Color(red: 0.84, green: 0.65, blue: 0.47) : Color(red: 0.55, green: 0.35, blue: 0.18)
    }
    private var focusColor: Color { entry.snapshot.phase == .gap ? upcomingAccent : accent }

    private var focusedTask: TaskOccurrence? {
        switch entry.snapshot.phase {
        case .current: entry.snapshot.current
        case .gap: entry.snapshot.next
        default: nil
        }
    }

    private func dateParts(_ date: String) -> (year: Int, month: Int, day: Int)? {
        let numbers = date.split(separator: "-").compactMap { Int($0) }
        guard numbers.count == 3 else { return nil }
        return (numbers[0], numbers[1], numbers[2])
    }

    private func weekYear(_ week: WeekPlan) -> String {
        guard let first = dateParts(week.weekStart), let last = dateParts(week.days[6].date) else { return "" }
        return first.year == last.year ? "\(first.year)" : "\(first.year) / \(last.year)"
    }

    private func weekMonth(_ week: WeekPlan) -> String {
        guard let first = dateParts(week.weekStart), let last = dateParts(week.days[6].date) else { return "" }
        if first.year == last.year && first.month == last.month {
            return "\(first.month)月"
        }
        return "\(first.month)月 / \(last.month)月"
    }

    var body: some View {
        let family = familyOverride ?? environmentFamily
        Group {
            if #available(iOS 27.0, *), family == .systemExtraLargePortrait {
                portraitView
            } else if family == .systemLarge {
                weekView(expanded: false)
            } else if family == .systemSmall {
                smallView
            } else {
                mediumView
            }
        }
        .containerBackground(for: .widget) { paper }
        .widgetURL(URL(string: "nextbeat://home"))
    }

    private var portraitView: some View {
        GeometryReader { geometry in
            let showsReflection = entry.reflection.isEnabled && !entry.reflection.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let quoteHeight: CGFloat = showsReflection ? min(36, max(22, scaledQuoteHeight)) : 0
            let headingHeight = min(47, max(34, scaledHeadingHeight))
            let needsMoreFocusHeight = focusedTask.map { $0.item.title.count > 17 || $0.item.tip.count > 24 } ?? false
            let footerHeight = min(180, max(needsMoreFocusHeight ? 104 : 84, scaledFocusHeight - 12))
            let showsFooterReflection = entry.reflection.footerEnabled &&
                !entry.reflection.footerText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let footerReflectionHeight: CGFloat = showsFooterReflection ? 27 : 0
            let dayHeaderHeight = min(50, max(38, min(scaledWeekday, 15) + min(scaledDayNumber, 21) + 8))
            let gridBudget = max(150, geometry.size.height - quoteHeight - headingHeight - footerHeight - footerReflectionHeight - 24 - 10)
            let nominalCellHeight = min(65, max(32, gridTimeSize + gridEndTimeSize + gridTitleSize + 5))
            let visibleSlots = max(1, min(10, Int((gridBudget - dayHeaderHeight) / nominalCellHeight)))
            let cellHeight = min(45, max(nominalCellHeight,
                                         (gridBudget - dayHeaderHeight) / CGFloat(visibleSlots)))

            VStack(alignment: .leading, spacing: 0) {
                if showsReflection {
                    HStack(spacing: 5) {
                        Image(systemName: "quote.opening")
                            .foregroundStyle(focusColor)
                        Text(entry.reflection.text)
                            .foregroundStyle(mutedInk)
                            .lineLimit(1)
                    }
                    .font(.caption2.weight(.medium))
                    .frame(height: quoteHeight, alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(alignment: .center) {
                    Text("NEXTBEAT")
                        .font(.caption.weight(.bold))
                        .tracking(1.5)
                        .foregroundStyle(ink)
                    Spacer(minLength: 4)
                    if let week = entry.week {
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(weekMonth(week))
                                .font(.system(size: 14, weight: .semibold, design: .rounded).monospacedDigit())
                                .foregroundStyle(ink)
                            Text(weekYear(week))
                                .font(.system(size: 8, weight: .medium, design: .rounded).monospacedDigit())
                                .tracking(1.0)
                                .foregroundStyle(mutedInk)
                        }
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)
                    }
                }
                .frame(height: headingHeight, alignment: .top)

                if let error = entry.error {
                    Spacer(minLength: 8)
                    Label("共享数据配置错误", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundStyle(accent)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(ink)
                    Spacer(minLength: 8)
                } else if let week = entry.week {
                    timetable(week, slots: visibleSlots, cellHeight: cellHeight, headerHeight: dayHeaderHeight)
                    Spacer(minLength: 6)
                    portraitFocusPanel(height: footerHeight)
                } else {
                    Spacer(minLength: 8)
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.title2)
                            .foregroundStyle(accent)
                        Text("本周没有计划")
                            .font(.headline)
                            .foregroundStyle(ink)
                        Text("轻点打开 App，导入完整七天日程。")
                            .font(.caption)
                            .foregroundStyle(mutedInk)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Spacer(minLength: 8)
                }
                if showsFooterReflection {
                    footerReflection
                        .frame(height: footerReflectionHeight, alignment: .bottom)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func timetable(_ week: WeekPlan, slots: Int, cellHeight: CGFloat, headerHeight: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(week.days.enumerated()), id: \.offset) { index, day in
                timetableColumn(day, index: index, slots: slots, cellHeight: cellHeight, headerHeight: headerHeight)
                    .frame(maxWidth: .infinity)
                if index < 6 {
                    Rectangle()
                        .fill(rule)
                        .frame(width: 0.5)
                }
            }
        }
        .frame(height: headerHeight + CGFloat(slots) * cellHeight)
        .background(surface, in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(rule, lineWidth: 0.5))
        .accessibilityLabel("七天课表，按每一天的开始时间顺序排列")
    }

    private func timetableColumn(_ day: PlanDay, index: Int, slots: Int, cellHeight: CGFloat, headerHeight: CGFloat) -> some View {
        let isToday = day.date == entry.snapshot.today
        let hasOverflow = day.items.count > slots
        let capacity = hasOverflow ? max(1, slots - 1) : slots
        let indices = portraitItemIndices(in: day, limit: capacity)
        let hiddenCount = day.items.count - indices.count
        let weekdays = ["周一", "周二", "周三", "周四", "周五", "周六", "周日"]
        let dayNumber = dateParts(day.date)?.day ?? index + 1

        return VStack(spacing: 0) {
            VStack(spacing: 1) {
                Text("\(dayNumber)")
                    .font(.system(size: min(scaledDayNumber, 12), weight: .medium, design: .rounded).monospacedDigit())
                    .foregroundStyle(isToday ? accent : mutedInk)
                    .frame(height: min(14, max(11, scaledDayNumber + 2)))
                Text(weekdays[index])
                    .font(.system(size: min(scaledWeekday, 15), weight: .semibold))
                    .foregroundStyle(isToday ? surface : ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .frame(minWidth: 32, minHeight: 22)
                    .background {
                        if isToday {
                            RoundedRectangle(cornerRadius: 6).fill(accent)
                        }
                    }
            }
            .frame(height: headerHeight)
            .frame(maxWidth: .infinity)
            .background(isToday ? accent.opacity(colorScheme == .dark ? 0.18 : 0.12) : Color.clear)
            .overlay(alignment: .bottom) {
                Rectangle().fill(rule).frame(height: 0.5)
            }

            ForEach(0..<slots, id: \.self) { slot in
                Group {
                    if slot < indices.count {
                        timetableTask(
                            day.items[indices[slot]], in: day, height: cellHeight,
                            showsDivider: slot + 1 < indices.count || hasOverflow
                        )
                    } else if hasOverflow && slot == indices.count {
                        VStack(spacing: 0) {
                            Text("+\(hiddenCount)")
                                .font(.system(size: min(scaledGridTitle, 17), weight: .semibold, design: .rounded))
                            Text("更多")
                                .font(.system(size: min(scaledGridTime, 14)))
                        }
                        .foregroundStyle(mutedInk)
                        .frame(height: cellHeight)
                        .frame(maxWidth: .infinity)
                        .accessibilityLabel("\(day.date) 还有 \(hiddenCount) 项未显示")
                    } else {
                        Color.clear.frame(height: cellHeight)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(isToday ? accent.opacity(colorScheme == .dark ? 0.10 : 0.065) : Color.clear)
    }

    private func timetableTask(_ item: ScheduleItem, in day: PlanDay, height: CGFloat, showsDivider: Bool) -> some View {
        let selected = isFocused(item, in: day)
        let upcoming = selected && entry.snapshot.phase == .gap
        let startColor = selected && !upcoming ? Color(red: 0.99, green: 0.97, blue: 0.94) : upcoming ? upcomingAccent : ink
        let endColor = selected && !upcoming ? Color(red: 0.97, green: 0.94, blue: 0.90).opacity(0.70) : mutedInk.opacity(0.78)
        let titleColor = selected && !upcoming ? Color(red: 0.99, green: 0.97, blue: 0.94) : ink

        return VStack(alignment: .leading, spacing: 0) {
            Text(item.start)
                .font(.system(size: gridTimeSize, weight: selected ? .bold : .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(startColor)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Text(item.end)
                .font(.system(size: gridEndTimeSize, weight: .regular, design: .rounded).monospacedDigit())
                .foregroundStyle(endColor)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            Text(item.title)
                .font(.system(size: gridTitleSize, weight: selected ? .semibold : .regular))
                .foregroundStyle(titleColor)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, 3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: height, alignment: .center)
        .background {
            if selected {
                RoundedRectangle(cornerRadius: 4)
                    .fill(upcoming ? focusColor.opacity(0.13) : Color(red: 0.17, green: 0.18, blue: 0.19))
                    .padding(.horizontal, 1)
                    .padding(.vertical, 1)
            }
        }
        .overlay(alignment: .leading) {
            if selected {
                RoundedRectangle(cornerRadius: 1)
                    .fill(focusColor)
                    .frame(width: 2, height: height - 4)
                    .padding(.leading, 1)
            }
        }
        .overlay(alignment: .bottom) {
            if showsDivider && !selected {
                Rectangle()
                    .fill(ink.opacity(colorScheme == .dark ? 0.23 : 0.20))
                    .frame(height: 0.75)
                    .padding(.horizontal, 4)
                    .padding(.bottom, 1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(day.date) \(item.start) 至 \(item.end) \(item.title)\(selected ? entry.snapshot.phase == .current ? "，正在进行" : "，下一项" : "")")
    }

    private func portraitItemIndices(in day: PlanDay, limit: Int) -> [Int] {
        guard day.items.count > limit else { return Array(day.items.indices) }
        if let task = focusedTask, task.day == day.date,
           let focusIndex = day.items.firstIndex(of: task.item), focusIndex >= limit {
            let start = min(max(0, focusIndex - limit / 2), day.items.count - limit)
            return Array(start..<(start + limit))
        }
        return Array(0..<limit)
    }

    private func portraitFocusPanel(height: CGFloat) -> some View {
        let heading: String = switch entry.snapshot.phase {
        case .current: "正在进行"
        case .gap: "下一项"
        case .done: "今日已完成"
        case .emptyDay: "今天没有安排"
        default: "本周没有计划"
        }
        let footerInk = Color(red: 0.98, green: 0.96, blue: 0.93)
        let footerAccent = entry.snapshot.phase == .gap
            ? Color(red: 0.90, green: 0.70, blue: 0.50)
            : Color(red: 1, green: 0.48, blue: 0.37)

        return VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Circle().fill(footerAccent).frame(width: 5, height: 5)
                Text(heading)
                if let task = focusedTask {
                    Text("· \(task.item.start)—\(task.item.end)")
                        .monospacedDigit()
                }
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(footerAccent)

            if let task = focusedTask {
                Text(task.item.title)
                    .font(.subheadline.bold())
                    .foregroundStyle(footerInk)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
                Rectangle().fill(footerInk.opacity(0.2)).frame(height: 0.5)
                Text(task.item.tip.isEmpty ? "未设置提醒语" : task.item.tip)
                    .font(.caption)
                    .foregroundStyle(footerInk.opacity(task.item.tip.isEmpty ? 0.6 : 0.9))
                    .lineLimit(2)
            } else {
                Text(entry.snapshot.phase == .done ? "今天的事项都已结束。" : "轻点打开 App 查看完整计划。")
                    .font(.caption)
                    .foregroundStyle(footerInk.opacity(0.85))
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: height, alignment: .top)
        .background(Color(red: 0.14, green: 0.15, blue: 0.16), in: RoundedRectangle(cornerRadius: 11))
    }

    private var footerReflection: some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            Text(entry.reflection.footerTitle)
                .font(.system(size: 8, weight: .bold))
                .tracking(1.1)
                .foregroundStyle(accent)
                .fixedSize()
            Text(entry.reflection.footerText)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(mutedInk)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 2)
        .overlay(alignment: .top) {
            Rectangle().fill(rule).frame(height: 0.5)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.reflection.footerTitle)：\(entry.reflection.footerText)")
    }

    private func weekView(expanded: Bool) -> some View {
        GeometryReader { geometry in
            let showsReflection = entry.reflection.isEnabled && !entry.reflection.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let reservedHeight: CGFloat = expanded ? (showsReflection ? 220 : 193) : (showsReflection ? 151 : 132)
            let rowHeight = expanded
                ? min(67, max(42, (geometry.size.height - reservedHeight) / 7))
                : min(29, max(22, (geometry.size.height - reservedHeight) / 7))

            VStack(alignment: .leading, spacing: 0) {
                if showsReflection {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Image(systemName: "quote.opening")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(accent)
                        Text(entry.reflection.text)
                            .font(expanded ? .subheadline.weight(.medium) : .caption.weight(.medium))
                            .lineLimit(expanded ? 2 : 1)
                            .minimumScaleFactor(0.85)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, expanded ? 10 : 6)
                }

                HStack(alignment: .firstTextBaseline) {
                    Text("一周节奏")
                        .font(expanded ? .title3.bold() : .subheadline.bold())
                    Spacer(minLength: 4)
                    if let week = entry.week {
                        Text("\(weekMonth(week)) · \(weekYear(week))")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    } else {
                        Text("NextBeat")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(accent)
                    }
                }
                .padding(.bottom, expanded ? 8 : 4)

                if let error = entry.error {
                    Spacer(minLength: 12)
                    Label("共享数据配置错误", systemImage: "exclamationmark.triangle.fill")
                        .font(.headline)
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption)
                        .lineLimit(5)
                    Spacer(minLength: 12)
                } else if let week = entry.week {
                    VStack(spacing: expanded ? 3 : 1) {
                        ForEach(Array(week.days.enumerated()), id: \.offset) { index, day in
                            weekDayRow(day, index: index, height: rowHeight, expanded: expanded)
                        }
                    }
                    Spacer(minLength: expanded ? 8 : 3)
                    focusPanel(expanded: expanded)
                } else {
                    Spacer(minLength: 12)
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.title2)
                            .foregroundStyle(accent)
                        Text("本周没有计划")
                            .font(.headline)
                        Text("轻点打开 App，导入从周一到周日的计划。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 12)
                }
            }
            .padding(expanded ? 18 : 14)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func weekDayRow(_ day: PlanDay, index: Int, height: CGFloat, expanded: Bool) -> some View {
        let isToday = day.date == entry.snapshot.today
        let maxItems: Int = dynamicTypeSize.isAccessibilitySize ? 1 : (expanded ? (height >= 48 ? 3 : 2) : 1)
        let indices = visibleItemIndices(in: day, limit: maxItems)
        let hiddenCount = day.items.count - indices.count

        return HStack(alignment: .center, spacing: expanded ? 9 : 6) {
            VStack(alignment: .leading, spacing: 1) {
                Text(["周一", "周二", "周三", "周四", "周五", "周六", "周日"][index])
                    .font(.caption2.weight(isToday ? .bold : .medium))
                if expanded {
                    Text(String(day.date.suffix(2)))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(isToday ? accent : .primary)
            .frame(width: expanded ? 33 : 27, alignment: .leading)

            RoundedRectangle(cornerRadius: 2)
                .fill(isToday ? accent : Color.primary.opacity(0.12))
                .frame(width: isToday ? 3 : 2)

            if day.items.isEmpty {
                Text("无安排")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: expanded ? 1 : 0) {
                    ForEach(indices, id: \.self) { itemIndex in
                        let item = day.items[itemIndex]
                        let highlighted = isFocused(item, in: day)
                        HStack(spacing: 3) {
                            if highlighted {
                                Image(systemName: "arrowtriangle.right.fill")
                                    .font(.system(size: 6))
                                    .accessibilityHidden(true)
                            }
                            Text("\(item.start)—\(item.end)")
                                .monospacedDigit()
                                .foregroundStyle(highlighted ? accent : .secondary)
                            Text(item.title)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .font(.caption2.weight(highlighted ? .semibold : .regular))
                        .foregroundStyle(highlighted ? accent : .primary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if hiddenCount > 0 {
                Text("+\(hiddenCount)")
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, expanded ? 8 : 5)
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .background(isToday ? accent.opacity(0.10) : Color.clear,
                    in: RoundedRectangle(cornerRadius: expanded ? 10 : 6))
        .accessibilityElement(children: .combine)
    }

    private func visibleItemIndices(in day: PlanDay, limit: Int) -> [Int] {
        guard day.items.count > limit else { return Array(day.items.indices) }
        var indices = Array(0..<limit)
        if let focus = focusedTask, focus.day == day.date,
           let focusIndex = day.items.firstIndex(of: focus.item), focusIndex >= limit {
            indices[limit - 1] = focusIndex
        }
        return indices
    }

    private func isFocused(_ item: ScheduleItem, in day: PlanDay) -> Bool {
        focusedTask.map { $0.day == day.date && $0.item == item } ?? false
    }

    private func focusPanel(expanded: Bool) -> some View {
        VStack(alignment: .leading, spacing: expanded ? 5 : 3) {
            if let task = focusedTask {
                HStack(spacing: 5) {
                    Image(systemName: entry.snapshot.phase == .current ? "bolt.fill" : "forward.fill")
                    Text(entry.snapshot.phase == .current
                         ? "正在进行 · \(task.item.start)—\(task.item.end)"
                         : "下一项 · \(task.item.start)—\(task.item.end)")
                }
                .font(.caption2.monospacedDigit().weight(.bold))
                .foregroundStyle(accent)
                Text(task.item.title)
                    .font(expanded ? .headline : .subheadline.bold())
                    .lineLimit(expanded ? 2 : 1)
                    .minimumScaleFactor(0.85)
                if expanded { Divider() }
                Text(task.item.tip.isEmpty ? "这项没有设置提醒语" : task.item.tip)
                    .font(expanded ? .subheadline : .caption2)
                    .foregroundStyle(task.item.tip.isEmpty ? Color.secondary : Color.primary)
                    .lineLimit(expanded ? 2 : 1)
            } else {
                let message: String = switch entry.snapshot.phase {
                case .done: "今日已完成"
                case .emptyDay: "今天没有安排"
                default: "本周没有计划"
                }
                Text(message)
                    .font(expanded ? .headline : .subheadline.bold())
                Text(entry.snapshot.phase == .done ? "今天的任务都已结束。" : "轻点打开 App 查看或调整计划。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(expanded ? 12 : 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: expanded ? 110 : 73, alignment: .top)
        .background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: expanded ? 14 : 10))
    }

    private var mediumView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("NextBeat", systemImage: "sun.max.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(accent)
                Spacer(minLength: 5)
                if let today = entry.snapshot.today {
                    Text(String(today.suffix(5)))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            if let error = entry.error {
                Text("共享数据配置错误")
                    .font(.headline)
                    .foregroundStyle(.red)
                Text(error)
                    .font(.caption2)
                    .lineLimit(3)
            } else {
                statusContent(isSmall: false)
            }
            Spacer(minLength: 0)
        }
        .padding(15)
    }

    private var smallView: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("NEXTBEAT")
                .font(.caption2.weight(.bold))
                .tracking(1)
                .foregroundStyle(accent)
            if entry.error != nil {
                Text("共享数据错误")
                    .font(.headline)
                    .foregroundStyle(.red)
                Text("轻点打开 App 查看配置")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } else {
                statusContent(isSmall: true)
            }
            Spacer(minLength: 0)
        }
        .padding(13)
    }

    @ViewBuilder
    private func statusContent(isSmall: Bool) -> some View {
        switch entry.snapshot.phase {
        case .current:
            if let current = entry.snapshot.current {
                Text("正在进行 · \(current.item.start)—\(current.item.end)")
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(current.item.title)
                    .font(isSmall ? .headline : .title3.bold())
                    .lineLimit(isSmall ? 2 : 2)
                    .minimumScaleFactor(0.8)
                if !current.item.tip.isEmpty {
                    Text(current.item.tip)
                        .font(isSmall ? .caption2 : .caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let next = entry.snapshot.next {
                    Text("下一项  \(next.item.start)—\(next.item.end)  \(next.item.title)")
                        .font(isSmall ? .caption2.monospacedDigit() : .caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .lineLimit(isSmall ? 2 : 1)
                } else if !isSmall {
                    Text("今天没有下一项")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        case .gap:
            if let next = entry.snapshot.next {
                Text("当前空档 · \(next.item.start)—\(next.item.end)")
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(next.item.title)
                    .font(isSmall ? .headline : .title3.bold())
                    .lineLimit(2)
                if !next.item.tip.isEmpty {
                    Text(next.item.tip)
                        .font(isSmall ? .caption2 : .caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(isSmall ? 1 : 2)
                }
            }
        case .done:
            Text("今日已完成")
                .font(isSmall ? .headline : .title3.bold())
            Text("今天的安排已结束")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .emptyDay:
            Text("今天没有安排")
                .font(isSmall ? .headline : .title3.bold())
            Text("享受这一天")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .noPlan:
            Text("本周没有计划")
                .font(isSmall ? .headline : .title3.bold())
            Text("轻点打开 App 导入七天日程")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }
}

struct NextBeatWidget: Widget {
    let kind = "NextBeatWidget"

    private var families: [WidgetFamily] {
        var result: [WidgetFamily] = [.systemSmall, .systemMedium, .systemLarge]
        if #available(iOS 27.0, *) { result.append(.systemExtraLargePortrait) }
        return result
    }

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: NextBeatProvider()) { entry in
            NextBeatWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("NextBeat 日程")
        .description("查看七天计划、当前事项与提醒语。")
        .supportedFamilies(families)
    }
}

@main
struct NextBeatWidgetBundle: WidgetBundle {
    var body: some Widget { NextBeatWidget() }
}

private func previewEntry(_ hour: Int, _ minute: Int, day: Int = 5,
                          plans: [WeekPlan] = [PreviewFixtures.week],
                          reflection: ReflectionSettings = .defaultValue) -> NextBeatEntry {
    let date = PreviewFixtures.time(hour, minute, day: day)
    return NextBeatEntry(date: date,
                         snapshot: PlanEngine.snapshot(in: plans, at: date),
                         week: PlanEngine.activePlan(in: plans, at: date),
                         reflection: reflection,
                         error: nil)
}

#Preview("中号 · 时间切换", as: .systemMedium, widget: {
    NextBeatWidget()
}, timeline: {
    previewEntry(9, 30)
    previewEntry(10, 45)
    previewEntry(11, 30)
    previewEntry(18, 0)
})

#Preview("中号 · 无计划", as: .systemMedium, widget: {
    NextBeatWidget()
}, timeline: {
    previewEntry(9, 30, plans: [])
})

#Preview("小号 · 当前任务", as: .systemSmall, widget: {
    NextBeatWidget()
}, timeline: {
    previewEntry(9, 30)
})

#Preview("深色模式") {
    NextBeatWidgetEntryView(entry: previewEntry(9, 30), familyOverride: .systemMedium)
        .frame(width: 329, height: 155)
        .preferredColorScheme(.dark)
}

#Preview("大号 · 七天与空档", as: .systemLarge, widget: {
    NextBeatWidget()
}, timeline: {
    previewEntry(9, 45, day: 7, plans: [PreviewFixtures.denseWeek])
    previewEntry(10, 20, day: 7, plans: [PreviewFixtures.denseWeek])
    previewEntry(21, 0, day: 7, plans: [PreviewFixtures.denseWeek])
})

#Preview("大号 · 无计划", as: .systemLarge, widget: {
    NextBeatWidget()
}, timeline: {
    previewEntry(9, 30, day: 7, plans: [])
})

#Preview("纵向超大 · 七天") {
    if #available(iOS 27.0, *) {
        NextBeatWidgetEntryView(entry: previewEntry(9, 45, day: 7, plans: [PreviewFixtures.denseWeek]),
                                familyOverride: .systemExtraLargePortrait)
            .frame(width: 350, height: 565)
    }
}

#Preview("纵向超大 · 空档与深色") {
    if #available(iOS 27.0, *) {
        NextBeatWidgetEntryView(entry: previewEntry(10, 20, day: 7, plans: [PreviewFixtures.denseWeek]),
                                familyOverride: .systemExtraLargePortrait)
            .frame(width: 350, height: 565)
            .preferredColorScheme(.dark)
    }
}

#Preview("纵向超大 · 大字无计划") {
    if #available(iOS 27.0, *) {
        NextBeatWidgetEntryView(entry: previewEntry(9, 30, day: 7, plans: []),
                                familyOverride: .systemExtraLargePortrait)
            .frame(width: 350, height: 565)
            .environment(\.dynamicTypeSize, .accessibility1)
    }
}

#Preview("纵向超大 · 长标题与大字") {
    if #available(iOS 27.0, *) {
        NextBeatWidgetEntryView(entry: previewEntry(17, 30, day: 7, plans: [PreviewFixtures.denseWeek]),
                                familyOverride: .systemExtraLargePortrait)
            .frame(width: 350, height: 565)
            .environment(\.dynamicTypeSize, .accessibility1)
    }
}

#Preview("纵向超大 · 关闭自省语") {
    if #available(iOS 27.0, *) {
        NextBeatWidgetEntryView(
            entry: previewEntry(9, 45, day: 7, plans: [PreviewFixtures.denseWeek],
                                reflection: ReflectionSettings(
                                    isEnabled: false,
                                    text: ReflectionSettings.defaultValue.text,
                                    footerEnabled: false,
                                    footerText: ReflectionSettings.defaultFooterText)),
            familyOverride: .systemExtraLargePortrait
        )
        .frame(width: 350, height: 565)
    }
}

#Preview("纵向超大 · 自定义底部标题") {
    if #available(iOS 27.0, *) {
        NextBeatWidgetEntryView(
            entry: previewEntry(9, 45, day: 7, plans: [PreviewFixtures.denseWeek],
                                reflection: ReflectionSettings(
                                    isEnabled: true,
                                    text: ReflectionSettings.defaultValue.text,
                                    footerTitle: "片刻自问")),
            familyOverride: .systemExtraLargePortrait
        )
        .frame(width: 350, height: 565)
    }
}
