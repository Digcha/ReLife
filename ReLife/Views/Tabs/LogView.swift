// Übersicht und Pflege der Notizen
import SwiftUI

struct LogView: View {
    @EnvironmentObject var app: AppState
    @State private var filter: NoteTag? = nil
    @State private var showAdd = false
    @State private var noteText: String = ""
    @State private var noteTag: NoteTag? = nil

    // Filtert die Notizen je nach ausgewähltem Tag
    private var filtered: [Note] {
        if let f = filter { return app.notes.filter { $0.tag == f } }
        return app.notes
    }

    var body: some View {
        VStack {
            // Auswahl für Tag-Filter
            Picker("Filter", selection: $filter) {
                Text("Alle").tag(NoteTag?.none)
                ForEach(NoteTag.allCases) { tag in
                    Text(tag.rawValue).tag(NoteTag?.some(tag))
                }
            }
            .pickerStyle(.segmented)
            .padding([.horizontal, .top])

            if filtered.isEmpty {
                // Leerer Zustand mit Hinweis und Schnellzugriff
                VStack(spacing: 8) {
                    Text("Noch keine Notizen.")
                        .foregroundColor(.secondary)
                    PrimaryButton(title: "+ Neue Notiz") { showAdd = true }
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Notizliste mit Datum und optionalen Tags
                List {
                    ForEach(filtered) { note in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(note.date, style: .date)
                                Text(note.date, style: .time)
                                    .foregroundColor(.secondary)
                                Spacer()
                                if let tag = note.tag { TagPill(text: tag.rawValue) }
                            }
                            Text(note.text)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(Text(note.text))
                    }
                    .onDelete { indexSet in
                        // Entfernt ausgewählte Notizen aus dem Zustand
                        let items = indexSet.map { filtered[$0] }
                        app.notes.removeAll { items.contains($0) }
                    }
                }
                .listStyle(.insetGrouped)
            }
        }
        .navigationTitle("Protokoll")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                // Neues Notiz-Formular öffnen
                Button(action: { showAdd = true }) {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(Text("Neue Notiz"))
            }
        }
        // Sheet zum Erfassen einer neuen Notiz
        .sheet(isPresented: $showAdd) {
            AddNoteSheet(noteText: $noteText, noteTag: $noteTag) {
                app.addNote(tag: noteTag, text: noteText)
                // Formular nach Speichern leeren
                noteText = ""
                noteTag = nil
            }
        }
    }
}

