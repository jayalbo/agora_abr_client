import SwiftUI
import UIKit

struct SplashView: View {
    var body: some View {
        ZStack {
            // Subtle background so launch feels intentional, not black
            LinearGradient(
                colors: [Color.agoraBlack, Color.agoraDarkBlue.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
                .ignoresSafeArea()

            VStack(spacing: 16) {
                LogoImage()
                    .frame(width: 180, height: 180)
                    .shadow(radius: 8)

                Text("Loading…")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
}

private struct LogoImage: View {
    var body: some View {
        if let ui = UIImage(named: "agora_a") { // Prefer the single "a" variant for loading
            Image(uiImage: ui)
                .resizable()
                .scaledToFit()
        } else if let ui = UIImage(named: "agora") { // Fallback to full logo asset name
            Image(uiImage: ui)
                .resizable()
                .scaledToFit()
        } else {
            // Fallback stylized "a" if assets are not present
            LogoFallback()
        }
    }
}

private struct LogoFallback: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.agoraBlue.opacity(0.15))
            Text("a")
                .font(.system(size: 96, weight: .bold, design: .rounded))
                .foregroundColor(Color.agoraBlue)
                .accessibilityLabel("Agora")
        }
    }
}

extension Color {
    // Agora brand palette
    static let agoraBlack = Color(red: 0/255, green: 0/255, blue: 0/255)          // #000000
    static let agoraBlue = Color(red: 0/255, green: 194/255, blue: 255/255)       // #00C2FF (primary blue)
    static let agoraDarkBlue = Color(red: 7/255, green: 92/255, blue: 154/255)    // #075C9A
    static let agoraNearBlack = Color(red: 15/255, green: 15/255, blue: 15/255)   // #0F0F0F
    static let agoraLightCyan = Color(red: 160/255, green: 250/255, blue: 255/255)// #A0FAFF (corrected hex)
    static let agoraGray = Color(red: 179/255, green: 179/255, blue: 179/255)     // #B3B3B3
    static let agoraPurple = Color(red: 196/255, green: 111/255, blue: 251/255)   // #C46FFB
    static let agoraViolet = Color(red: 148/255, green: 67/255, blue: 199/255)    // #9443C7
    static let agoraOffWhite = Color(red: 252/255, green: 249/255, blue: 248/255) // #FCF9F8

    // UI palette (subset)
    static let uiBlack = agoraBlack
    static let uiNearBlack = agoraNearBlack      // #0F0F0F
    static let uiGray3 = Color(red: 23/255, green: 23/255, blue: 23/255)   // #171717
    static let uiGray4 = Color(red: 44/255, green: 44/255, blue: 44/255)   // #2C2C2C
    static let uiGray5 = Color(red: 72/255, green: 72/255, blue: 72/255)   // #484848
    static let uiGray6 = Color(red: 98/255, green: 98/255, blue: 98/255)   // #626262
    static let uiGray7 = Color(red: 179/255, green: 179/255, blue: 179/255)// #B3B3B3
    static let uiGray8 = Color(red: 214/255, green: 214/255, blue: 214/255)// #D6D6D6
    static let uiGray9 = Color(red: 239/255, green: 230/255, blue: 230/255)// #EFE6E6 (corrected typo)

    // Alerts
    static let alertGreen = Color(red: 66/255, green: 176/255, blue: 61/255)  // #42B03D
    static let alertYellow = Color(red: 220/255, green: 163/255, blue: 17/255)// #DCA311
    static let alertRed = Color(red: 222/255, green: 52/255, blue: 74/255)    // #DE344A
}
