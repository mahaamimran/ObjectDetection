import SwiftUI

struct LaunchView: View {
    @State private var showCamera = false

    var body: some View {
        ZStack {
            Constants.Colors.systemBackground
                .ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()

                Image(systemName: Constants.Images.iconName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .foregroundColor(Constants.Colors.primary)

                Text(Constants.Strings.appTitle)
                    .font(.custom(Constants.Fonts.lexendBold, size: 32))
                    .foregroundColor(Constants.Colors.primary)

                Text(Constants.Strings.appDescription)
                    .font(.custom(Constants.Fonts.lexendRegular, size: 16))
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Spacer()

                Button(action: {
                    showCamera = true
                }) {
                    Text(Constants.Strings.getStarted)
                        .font(.custom(Constants.Fonts.lexendSemiBold, size: 18))
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Constants.Colors.primary)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.horizontal)
                }

                Spacer(minLength: 40)
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView()
        }
    }
}

#Preview {
    LaunchView()
}
