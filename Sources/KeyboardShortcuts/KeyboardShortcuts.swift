import Cocoa

/**
Global keyboard shortcuts for your macOS app.
*/
public enum KeyboardShortcuts {
	/// :nodoc:
	public typealias KeyAction = () -> Void

	private static var registeredShortcuts = Set<Shortcut>()

	// Not currently used. For the future.
	private static var keyDownHandlers = [Shortcut: [KeyAction]]()
	private static var keyUpHandlers = [Shortcut: [KeyAction]]()

	private static var userDefaultsKeyDownHandlers = [Name: [KeyAction]]()
	private static var userDefaultsKeyUpHandlers = [Name: [KeyAction]]()

	/// When `true`, event handlers will not be called for registered keyboard shortcuts.
	static var isPaused = false

	/**
	Reset the keyboard shortcut for one or more names.

	If the `Name` has a default shortcut, it will reset to that.

	```
	import SwiftUI
	import KeyboardShortcuts

	struct PreferencesView: View {
		var body: some View {
			VStack {
				// …
				Button("Reset All") {
					KeyboardShortcuts.reset(
						.toggleUnicornMode,
						.showRainbow
					)
				}
			}
		}
	}
	```
	*/
	public static func reset(_ names: Name...) {
		reset(names)
	}

	/**
	Reset the keyboard shortcut for one or more names.

	If the `Name` has a default shortcut, it will reset to that.

	- Note: This overload exists as Swift doesn't support splatting.

	```
	import SwiftUI
	import KeyboardShortcuts

	struct PreferencesView: View {
		var body: some View {
			VStack {
				// …
				Button("Reset All") {
					KeyboardShortcuts.reset(
						.toggleUnicornMode,
						.showRainbow
					)
				}
			}
		}
	}
	```
	*/
	public static func reset(_ names: [Name]) {
		for name in names {
			setShortcut(name.defaultShortcut, for: name)
		}
	}

	/**
	Set the keyboard shortcut for a name.

	Setting it to `nil` removes the shortcut, even if the `Name` has a default shortcut defined. Use `.reset()` if you want it to respect the default shortcut.

	You would usually not need this as the user would be the one setting the shortcut in a preferences user-interface, but it can be useful when, for example, migrating from a different keyboard shortcuts package.
	*/
	public static func setShortcut(_ shortcut: Shortcut?, for name: Name) {
		guard let shortcut = shortcut else {
			userDefaultsRemove(name: name)
			return
		}

		userDefaultsSet(name: name, shortcut: shortcut)
	}

	/**
	Get the keyboard shortcut for a name.
	*/
	public static func getShortcut(for name: Name) -> Shortcut? {
		guard
			let data = UserDefaults.standard.string(forKey: userDefaultsKey(for: name))?.data(using: .utf8),
			let decoded = try? JSONDecoder().decode(Shortcut.self, from: data)
		else {
			return nil
		}

		return decoded
	}

	private static let userDefaultsPrefix = "KeyboardShortcuts_"

	private static func userDefaultsKey(for shortcutName: Name) -> String {
        "\(userDefaultsPrefix)\(shortcutName.rawValue)"
	}

	static func userDefaultsDidChange(name: Name) {
		// TODO: Use proper UserDefaults observation instead of this.
		NotificationCenter.default.post(name: .shortcutByNameDidChange, object: nil, userInfo: ["name": name])
	}

	static func userDefaultsSet(name: Name, shortcut: Shortcut) {
		guard let encoded = try? JSONEncoder().encode(shortcut).string else {
			return
		}

		UserDefaults.standard.set(encoded, forKey: userDefaultsKey(for: name))
		userDefaultsDidChange(name: name)
	}

	static func userDefaultsRemove(name: Name) {
		if getShortcut(for: name) == nil {
			return
		}
		UserDefaults.standard.set(false, forKey: userDefaultsKey(for: name))
		userDefaultsDidChange(name: name)
	}

	static func userDefaultsContains(name: Name) -> Bool {
		UserDefaults.standard.object(forKey: userDefaultsKey(for: name)) != nil
	}
}

extension Notification.Name {
	static let shortcutByNameDidChange = Self("KeyboardShortcuts_shortcutByNameDidChange")
}
