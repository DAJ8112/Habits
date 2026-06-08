import SwiftUI
import SwiftData
import WidgetKit

/// Home screen: a list of all habits.
struct HabitListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Habit.sortOrder) private var habits: [Habit]
    @State private var showingAdd = false
    @State private var showingWidgetPreview = false
    @State private var path: [Habit] = []

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if habits.isEmpty {
                    ContentUnavailableView(
                        "No habits yet",
                        systemImage: "square.grid.3x3.fill",
                        description: Text("Tap + to add your first habit.")
                    )
                } else {
                    List {
                        ForEach(habits) { habit in
                            NavigationLink(value: habit) {
                                HabitRowView(habit: habit)
                            }
                        }
                        .onDelete(perform: deleteHabits)
                    }
                }
            }
            .navigationTitle("Habits")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            showingWidgetPreview = true
                        } label: {
                            Label("Widget preview", systemImage: "rectangle.3.group")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .navigationDestination(for: Habit.self) { habit in
                HabitDetailView(habit: habit)
            }
            .sheet(isPresented: $showingAdd) {
                AddEditHabitView(habit: nil)
            }
            .sheet(isPresented: $showingWidgetPreview) {
                WidgetPreviewView()
            }
        }
        .onAppear(perform: maybeAutoOpen)
        .onChange(of: habits.map(\.id)) { _, _ in maybeAutoOpen() }
    }

    /// Dev-only: jump straight to the first habit's detail when launched with
    /// OPEN_FIRST_HABIT=1 (used for screenshots). No-op in normal use.
    private func maybeAutoOpen() {
        let env = ProcessInfo.processInfo.environment
        if env["OPEN_ADD"] == "1" { showingAdd = true }
        if env["WIDGET_PREVIEW"] == "1" { showingWidgetPreview = true }
        guard env["OPEN_FIRST_HABIT"] == "1",
              path.isEmpty, let first = habits.first else { return }
        path = [first]
    }

    private func deleteHabits(_ offsets: IndexSet) {
        for index in offsets {
            let habit = habits[index]
            NotificationManager.cancel(id: habit.id)
            context.delete(habit)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }
}

/// A single row in the habit list.
struct HabitRowView: View {
    let habit: Habit

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(hex: habit.colorHex).opacity(0.2))
                        .frame(width: 40, height: 40)
                    Image(systemName: habit.iconSymbol)
                        .foregroundStyle(Color(hex: habit.colorHex))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.name)
                        .font(.headline)
                    Text(habit.trackingType == .count ? "Goal: \(habit.goalAmount)/day" : "Daily")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            // Read-only recent heatmap (no onTap → taps fall through to the row link).
            HeatmapView(source: habit, weeks: 18, cellSize: 11, spacing: 2.5)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    HabitListView()
        .modelContainer(for: [Habit.self, HabitEntry.self], inMemory: true)
}
