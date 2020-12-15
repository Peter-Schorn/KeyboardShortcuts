import Carbon.HIToolbox

private func carbonKeyboardShortcutsEventHandler(eventHandlerCall: EventHandlerCallRef?, event: EventRef?, userData: UnsafeMutableRawPointer?) -> OSStatus {
	CarbonKeyboardShortcuts.handleEvent(event)
}

enum CarbonKeyboardShortcuts {
	private final class HotKey {
		let shortcut: KeyboardShortcuts.Shortcut
		let carbonHotKeyId: Int
		let carbonHotKey: EventHotKeyRef
		let onKeyDown: (KeyboardShortcuts.Shortcut) -> Void
		let onKeyUp: (KeyboardShortcuts.Shortcut) -> Void

		init(
			shortcut: KeyboardShortcuts.Shortcut,
			carbonHotKeyID: Int,
			carbonHotKey: EventHotKeyRef,
			onKeyDown: @escaping (KeyboardShortcuts.Shortcut) -> Void,
			onKeyUp: @escaping (KeyboardShortcuts.Shortcut) -> Void
		) {
			self.shortcut = shortcut
			self.carbonHotKeyId = carbonHotKeyID
			self.carbonHotKey = carbonHotKey
			self.onKeyDown = onKeyDown
			self.onKeyUp = onKeyUp
		}
	}

	private static var hotKeys = [Int: HotKey]()

	// `SSKS` is just short for `Sindre Sorhus Keyboard Shortcuts`.
	private static let hotKeySignature = UTGetOSTypeFromString("SSKS" as CFString)

	private static var hotKeyId = 0
	private static var eventHandler: EventHandlerRef?

	fileprivate static func handleEvent(_ event: EventRef?) -> OSStatus {
		guard let event = event else {
			return OSStatus(eventNotHandledErr)
		}

		var eventHotKeyId = EventHotKeyID()
		let error = GetEventParameter(
			event,
			UInt32(kEventParamDirectObject),
			UInt32(typeEventHotKeyID),
			nil,
			MemoryLayout<EventHotKeyID>.size,
			nil,
			&eventHotKeyId
		)

		guard error == noErr else {
			return error
		}

		guard
			eventHotKeyId.signature == hotKeySignature,
			let hotKey = hotKeys[Int(eventHotKeyId.id)]
		else {
			return OSStatus(eventNotHandledErr)
		}

		switch Int(GetEventKind(event)) {
		case kEventHotKeyPressed:
			hotKey.onKeyDown(hotKey.shortcut)
			return noErr
		case kEventHotKeyReleased:
			hotKey.onKeyUp(hotKey.shortcut)
			return noErr
		default:
			break
		}

		return OSStatus(eventNotHandledErr)
	}
}

extension CarbonKeyboardShortcuts {
	static var system: [KeyboardShortcuts.Shortcut] {
		var shortcutsUnmanaged: Unmanaged<CFArray>?
		guard
			CopySymbolicHotKeys(&shortcutsUnmanaged) == noErr,
			let shortcuts = shortcutsUnmanaged?.takeRetainedValue() as? [[String: Any]]
		else {
			assertionFailure("Could not get system keyboard shortcuts")
			return []
		}

		return shortcuts.compactMap {
			guard
				($0[kHISymbolicHotKeyEnabled] as? Bool) == true,
				let carbonKeyCode = $0[kHISymbolicHotKeyCode] as? Int,
				let carbonModifiers = $0[kHISymbolicHotKeyModifiers] as? Int
			else {
				return nil
			}

			return KeyboardShortcuts.Shortcut(
				carbonKeyCode: carbonKeyCode,
				carbonModifiers: carbonModifiers
			)
		}
	}
}
