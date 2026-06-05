import SwiftUI

struct IntruderLogView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Access Log").font(.headline)
                Spacer()
                Button("Clear", role: .destructive) { model.clearIntruderLog() }
                    .disabled(model.intruderEvents.isEmpty)
            }
            if model.intruderEvents.isEmpty {
                Text("No recorded access attempts.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(model.intruderEvents.reversed()) { event in
                    HStack(spacing: 10) {
                        thumbnail(for: event)
                        VStack(alignment: .leading) {
                            Text(event.wasSuccessful ? "Unlocked" : "Failed attempt")
                                .foregroundStyle(event.wasSuccessful ? .green : .red)
                            Text(event.timestamp.formatted(date: .abbreviated, time: .standard))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
    }

    @ViewBuilder
    private func thumbnail(for event: IntruderEvent) -> some View {
        if let data = model.intruderImage(for: event), let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable().scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            Image(systemName: event.imageFilename == nil ? "person.fill.questionmark" : "photo")
                .frame(width: 44, height: 44)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
        }
    }
}
