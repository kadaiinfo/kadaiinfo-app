import Flutter
import UIKit

/// Apple 純正の Liquid Glass マテリアルを Flutter へ提供するプラットフォームビュー。
///
/// ぼかし量・彩度・縁の光沢・影・屈折といった見た目の数値は Apple が公開しておらず、
/// すべて OS が描画する。したがってこのファイルでは独自の見た目を一切作らず、
/// 公開されている API のパラメータだけを Dart 側から受け取って渡す。
///
/// 使用する公式 API:
///   - UIGlassEffect(style:)        ... .regular / .clear
///   - UIGlassEffect.interactive    ... タッチに反応して歪む挙動
///   - UIGlassEffect.tintColor      ... ガラスの色味
///   - UIGlassContainerEffect.spacing ... 複数のガラスが融合し始める距離
///   - UIView.cornerConfiguration = .capsule() ... 同心円状のカプセル角丸
///
/// iOS 26 未満では UIGlassEffect が存在しないため、同じく Apple 純正の
/// UIBlurEffect(.systemUltraThinMaterial) にフォールバックする。
final class LiquidGlassNavBarFactory: NSObject, FlutterPlatformViewFactory {
  static let viewType = "kadaiinfo/liquid_glass_nav_bar"

  private let messenger: FlutterBinaryMessenger

  init(messenger: FlutterBinaryMessenger) {
    self.messenger = messenger
    super.init()
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    return FlutterStandardMessageCodec.sharedInstance()
  }

  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    return LiquidGlassNavBarPlatformView(
      frame: frame,
      viewId: viewId,
      arguments: args as? [String: Any] ?? [:],
      messenger: messenger
    )
  }
}

final class LiquidGlassNavBarPlatformView: NSObject, FlutterPlatformView {
  private let barView: LiquidGlassNavBarView
  private let channel: FlutterMethodChannel

  init(
    frame: CGRect,
    viewId: Int64,
    arguments: [String: Any],
    messenger: FlutterBinaryMessenger
  ) {
    barView = LiquidGlassNavBarView(frame: frame, arguments: arguments)
    channel = FlutterMethodChannel(
      name: "\(LiquidGlassNavBarFactory.viewType)_\(viewId)",
      binaryMessenger: messenger
    )
    super.init()

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterMethodNotImplemented)
        return
      }
      switch call.method {
      case "setSelection":
        let args = call.arguments as? [String: Any] ?? [:]
        self.barView.updateSelection(
          index: args["selectedIndex"] as? Int ?? 0,
          itemCount: args["itemCount"] as? Int ?? 1,
          animated: args["animated"] as? Bool ?? true
        )
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func view() -> UIView {
    return barView
  }

  deinit {
    channel.setMethodCallHandler(nil)
  }
}

final class LiquidGlassNavBarView: UIView {
  /// ガラス要素をまとめる容器。iOS 26 以降でのみ生成する。
  private var containerEffectView: UIVisualEffectView?

  /// バー本体のガラス。
  private let barEffectView: UIVisualEffectView

  /// 選択中の項目に敷くガラス。nil のときは表示しない。
  private var selectionEffectView: UIVisualEffectView?

  private var itemCount: Int
  private var selectedIndex: Int
  private let selectionInset: CGFloat

  init(frame: CGRect, arguments: [String: Any]) {
    itemCount = max(arguments["itemCount"] as? Int ?? 1, 1)
    selectedIndex = arguments["selectedIndex"] as? Int ?? 0
    selectionInset = CGFloat(arguments["selectionInset"] as? Double ?? 4.0)

    let interactive = arguments["interactive"] as? Bool ?? false
    let showSelection = arguments["showSelection"] as? Bool ?? true

    if #available(iOS 26.0, *) {
      let effect = UIGlassEffect(
        style: LiquidGlassNavBarView.glassStyle(arguments["glassStyle"])
      )
      effect.isInteractive = interactive
      if let tint = LiquidGlassNavBarView.color(from: arguments["tintColor"]) {
        effect.tintColor = tint
      }
      barEffectView = UIVisualEffectView(effect: effect)
    } else {
      barEffectView = UIVisualEffectView(
        effect: UIBlurEffect(style: .systemUltraThinMaterial)
      )
    }

    super.init(frame: frame)

    // タップは Flutter 側のウィジェットで処理するため、ネイティブ側は透過させる。
    isUserInteractionEnabled = false
    backgroundColor = .clear

    if #available(iOS 26.0, *) {
      let containerEffect = UIGlassContainerEffect()
      containerEffect.spacing = CGFloat(arguments["containerSpacing"] as? Double ?? 0.0)
      let container = UIVisualEffectView(effect: containerEffect)
      container.frame = bounds
      container.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      addSubview(container)
      containerEffectView = container

      // ヘッダの記載どおり、個々のガラスは容器の contentView に入れ子にする。
      container.contentView.addSubview(barEffectView)

      if showSelection {
        let selectionEffect = UIGlassEffect(
          style: LiquidGlassNavBarView.glassStyle(arguments["selectionGlassStyle"])
        )
        if let tint = LiquidGlassNavBarView.color(from: arguments["selectionTintColor"]) {
          selectionEffect.tintColor = tint
        }
        let selection = UIVisualEffectView(effect: selectionEffect)
        selection.cornerConfiguration = .capsule()
        container.contentView.addSubview(selection)
        selectionEffectView = selection
      }

      barEffectView.cornerConfiguration = .capsule()
    } else {
      addSubview(barEffectView)
      barEffectView.clipsToBounds = true
      barEffectView.layer.cornerCurve = .continuous
    }
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    barEffectView.frame = bounds
    if #unavailable(iOS 26.0) {
      // iOS 26 未満は cornerConfiguration が無いので手動でカプセル形にする。
      barEffectView.layer.cornerRadius = bounds.height / 2.0
    }
    layoutSelection(animated: false)
  }

  func updateSelection(index: Int, itemCount: Int, animated: Bool) {
    self.itemCount = max(itemCount, 1)
    selectedIndex = min(max(index, 0), self.itemCount - 1)
    layoutSelection(animated: animated)
  }

  private func layoutSelection(animated: Bool) {
    guard let selection = selectionEffectView else { return }
    let target = selectionFrame()
    guard animated else {
      selection.frame = target
      return
    }
    if #available(iOS 17.0, *) {
      // 引数は UIKit の既定値そのまま。独自のカーブは与えない。
      UIView.animate(springDuration: 0.5, bounce: 0.0) {
        selection.frame = target
      }
    } else {
      UIView.animate(withDuration: 0.3) {
        selection.frame = target
      }
    }
  }

  private func selectionFrame() -> CGRect {
    let itemWidth = bounds.width / CGFloat(itemCount)
    return CGRect(
      x: itemWidth * CGFloat(selectedIndex) + selectionInset,
      y: selectionInset,
      width: max(itemWidth - selectionInset * 2.0, 0.0),
      height: max(bounds.height - selectionInset * 2.0, 0.0)
    )
  }

  @available(iOS 26.0, *)
  private static func glassStyle(_ raw: Any?) -> UIGlassEffect.Style {
    return (raw as? String) == "clear" ? .clear : .regular
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
