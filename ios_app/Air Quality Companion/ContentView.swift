import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: AirQualityViewModel
    @Environment(\.managedObjectContext) private var context

    init() {
        let context = PersistenceController.shared.container.viewContext
        _viewModel = StateObject(wrappedValue: AirQualityViewModel(context: context))
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Air Quality Readings")
                .font(.title)
                .padding()

            Text("PM1.0: \(viewModel.currentPM1_0) µg/m³")
                .font(.headline)
            Text("PM2.5: \(viewModel.currentPM2_5) µg/m³")
                .font(.headline)
            Text("PM10: \(viewModel.currentPM10) µg/m³")
                .font(.headline)

            Spacer()
        }
        .padding()
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
