import Flutter
import UIKit

/// Apple 純正の Liquid Glass マテリアルを Flutter へ提供するプラットフォームビュー。
///
/// ぼかし量・彩度・縁の光沢・影・屈折といった見た目の数値は Apple が公開しておらず、
/// すべて OS が描画する。したがってこのファイルでは独自の見た目を一切作らず、
/// 公開されている API のパラメータだけを Dart 側から受け取って渡す。
///
/// 使用する公式 API:
///   - UIGlassEffect(style:)       ... .regular / .clear
///   - UIGlassEffect.isInteractive ... タッチに反応して歪む挙動
///   - UIGlassEffect.tintColor     ... ガラスの色味
///   - UIView.cornerConfiguration = .capsule() ... 同心円状のカプセル角丸
///
/// iOS 26 未満では UIGlassEffect が存在しないため、同じく Apple 純正の
/// UIBlurEffect(.systemUltraThinMaterial) にフォールバックする。
///
/// ナビゲーションバーの選択中を示すカプセルはここでは描かない。ガラスを 2 枚
/// 重ねると UIGlassContainerEffect の有無にかかわらず色味を細かく制御できず、
/// Android と見た目も揃わないため、Flutter 側で単色のカプセルとして描いている。
final class LiquidGlassFactory: NSObject, FlutterPlatformViewFactory {
  static let viewType = "kadaiinfo/liquid_glass"

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    return FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    return LiquidGlassPlatformView(
      frame: frame,
      arguments: args as? [String: Any] ?? [:]
    )
  }
}

final class LiquidGlassPlatformView: NSObject, FlutterPlatformView {
  private let glassView: LiquidGlassView

  init(frame: CGRect, arguments: [String: Any]) {
    glassView = LiquidGlassView(frame: frame, arguments: arguments)
    super.init()
  }

  func view() -> UIView {
    return glassView
  }
}

final class LiquidGlassView: UIView {
  private let glassEffectView: UIVisualEffectView

  init(frame: CGRect, arguments: [String: Any]) {
    let interactive = arguments["interactive"] as? Bool ?? false

    if #available(iOS 26.0, *) {
      let effect = UIGlassEffect(
        style: (arguments["glassStyle"] as? String) == "clear" ? .clear : .regular
      )
      effect.isInteractive = interactive
      if let tint = LiquidGlassView.color(from: arguments["tintColor"]) {
        effect.tintColor = tint
      }
      glassEffectView = UIVisualEffectView(effect: effect)
    } else {
      glassEffectView = UIVisualEffectView(
        effect: UIBlurEffect(style: .systemUltraThinMaterial)
      )
    }

    super.init(frame: frame)

    // タップは Flutter 側のウィジェットで処理するため、ネイティブ側は透過させる。
    isUserInteractionEnabled = false
    backgroundColor = .clear
    addSubview(glassEffectView)

    if #available(iOS 26.0, *) {
      glassEffectView.cornerConfiguration = .capsule()
    } else {
      glassEffectView.clipsToBounds = true
      glassEffectView.layer.cornerCurve = .continuous
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    glassEffectView.frame = bounds
    if #unavailable(iOS 26.0) {
      // iOS 26 未満は cornerConfiguration が無いので手動でカプセル形にする。
      glassEffectView.layer.cornerRadius = bounds.height / 2.0
    }
  }

  /// Dart 側からは 0xAARRGGBB の整数で受け取る。
  private static func color(from raw: Any?) -> UIColor? {
    guard let value = raw as? Int else { return nil }
    return UIColor(
      red: CGFloat((value >> 16) & 0xFF) / 255.0,
      green: CGFloat((value >> 8) & 0xFF) / 255.0,
      blue: CGFloat(value & 0xFF) / 255.0,
      alpha: CGFloat((value >> 24) & 0xFF) / 255.0
    )
  }
}
