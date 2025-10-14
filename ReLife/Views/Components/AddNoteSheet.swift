import SwiftUI

// Formular, um eine Notiz schnell anzulegen
struct AddNoteSheet: View {
    @Binding var noteText: String
    @Binding var noteTag: NoteTag?
    var onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Tag") {
                    Picker("Tag", selection: $noteTag) {
                        Text("Kein Tag").tag(NoteTag?.none)
                        ForEach(NoteTag.allCases) { tag in
                            Text(tag.rawValue).tag(NoteTag?.some(tag))
                        }
                    }
                }
                Section("Notiz") {
                    TextEditor(text: $noteText)
                        .frame(height: 120)
                }
            }
            .navigationTitle("Neue Notiz")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        // Änderungen an den Aufrufer zurückgeben
                        onSave()
                        dismiss()
                    }
                    .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
