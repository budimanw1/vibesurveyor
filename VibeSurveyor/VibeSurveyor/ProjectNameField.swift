import SwiftUI

/// A compact text field that lets the user enter and persist a project name.
///
/// Reads and writes through `@AppStorage("projectName")` so the value
/// survives app launches with a default of "NoProject" (Requirements 9.1, 9.3, 9.4).
struct ProjectNameField: View {

    @AppStorage("projectName") private var projectName: String = "NoProject"

    var body: some View {
        HStack {
            Text("Project:")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(.white)

            TextField("Enter project name…", text: $projectName)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled(true)
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(8)
        .background(Color.black.opacity(0.6))
        .cornerRadius(6)
    }
}
