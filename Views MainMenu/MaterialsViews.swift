import SwiftUI
import PDFKit

// MARK: - Materials List View

struct MaterialsListView: View {
    let materials: [(title: String, url: URL)]
    let onSelectPDF: (URL, String) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Course Materials")
                        .font(.title2.weight(.bold))
                    Text("Tap a document to view it")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
            
            Divider()
            
            // Materials buttons
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(materials.enumerated()), id: \.offset) { _, item in
                        MaterialButton(
                            title: item.title,
                            url: item.url,
                            onTap: { onSelectPDF(item.url, item.title) }
                        )
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - Material Button Component

private struct MaterialButton: View {
    let title: String
    let url: URL
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // PDF icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.accentColor.opacity(0.1))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "doc.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.accentColor)
                }
                
                // File name
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    Text("PDF Document")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(.secondarySystemBackground))
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Materials Picker View

struct MaterialsPickerView: View {
    let candidates: [([String: Any], String)]
    let onSelect: ([String: Any]) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Select Course")
                        .font(.title2.weight(.bold))
                    Text("Multiple courses found. Select the correct one.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
            
            Divider()
            
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array(candidates.enumerated()), id: \.offset) { _, candidate in
                        let answers = candidate.0
                        let title = candidate.1
                        
                        Button {
                            onSelect(answers)
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.accentColor)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(title)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    if let dateField = answers["10"] as? [String: Any],
                                       let dateText = dateField["answer"] as? String {
                                        Text(dateText)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color(.secondarySystemBackground))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
        }
    }
}

// MARK: - PDF Viewer

struct PDFViewerView: View {
    let url: URL
    let title: String
    let onBack: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // PDF header with back button
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Back to Materials")
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Text(title)
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
            }
            .padding()
            .background(Color(.systemBackground))
            
            Divider()
            
            // PDF content
            MaterialsPDFView(url: url)
        }
    }
}

// MARK: - PDFKit Wrapper

struct MaterialsPDFView: UIViewRepresentable {
    let url: URL
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .systemBackground
        
        // Enable smooth scrolling
        pdfView.maxScaleFactor = 4.0
        pdfView.minScaleFactor = pdfView.scaleFactorForSizeToFit
        
        if let doc = PDFDocument(url: url) {
            pdfView.document = doc
        }
        
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        if pdfView.document?.documentURL != url {
            if let doc = PDFDocument(url: url) {
                pdfView.document = doc
            }
        }
    }
}

// MARK: - Preview Providers

#if DEBUG
struct MaterialsListView_Previews: PreviewProvider {
    static var previews: some View {
        MaterialsListView(
            materials: [
                ("Course Syllabus.pdf", URL(string: "https://example.com/syllabus.pdf")!),
                ("Student Handbook.pdf", URL(string: "https://example.com/handbook.pdf")!),
                ("Reference Guide.pdf", URL(string: "https://example.com/guide.pdf")!)
            ],
            onSelectPDF: { _, _ in }
        )
    }
}

struct PDFViewerView_Previews: PreviewProvider {
    static var previews: some View {
        PDFViewerView(
            url: URL(string: "https://example.com/sample.pdf")!,
            title: "Course Syllabus.pdf",
            onBack: {}
        )
    }
}
#endif
