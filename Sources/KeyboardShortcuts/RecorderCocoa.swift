import Cocoa
import Carbon.HIToolbox
import SwiftUI

extension KeyboardShortcuts {
	/**
	A `NSView` that lets the user record a keyboard shortcut.

	You would usually put this in your preferences window.

	It automatically prevents choosing a keyboard shortcut that is already taken by the system or by the app's main menu by showing a user-friendly alert to the user.

	It takes care of storing the keyboard shortcut in `UserDefaults` for you.

	```
	import Cocoa
	import KeyboardShortcuts

	final class PreferencesViewController: NSViewController {
		override func loadView() {
			view = NSView()

			let recorder = KeyboardShortcuts.RecorderCocoa(for: .toggleUnicornMode)
			view.addSubview(recorder)
		}
	}
	```
	*/
	public final class RecorderCocoa: NSSearchField, NSSearchFieldDelegate {
		private let minimumWidth: Double = 130
		private var eventMonitor: LocalEventMonitor?
		private let onChange: ((_ shortcut: Shortcut?) -> Void)?
		private var observer: NSObjectProtocol?

		/// The shortcut name for the recorder.
		/// Can be dynamically changed at any time.
		public var shortcutName: Name {
			didSet {
				guard shortcutName != oldValue else {
					return
				}

				setStringValue(name: shortcutName)

				DispatchQueue.main.async { [self] in
					// Prevents the placeholder from being cut off.
					blur()
				}
			}
		}

		/// :nodoc:
		override public var canBecomeKeyView: Bool { false }

		/// :nodoc:
		override public var intrinsicContentSize: CGSize {
			var size = super.intrinsicContentSize
			size.width = CGFloat(minimumWidth)
			return size
		}

		private var cancelButton: NSButtonCell?

		private var showsCancelButton: Bool {
			get { (cell as? NSSearchFieldCell)?.cancelButtonCell != nil }
			set {
				(cell as? NSSearchFieldCell)?.cancelButtonCell = newValue ? cancelButton : nil
			}
		}

		/**
		- Parameter name: Strongly-typed keyboard shortcut name.
		- Parameter onChange: Callback which will be called when the keyboard shortcut is changed/removed by the user. This can be useful when you need more control. For example, when migrating from a different keyboard shortcut solution and you need to store the keyboard shortcut somewhere yourself instead of relying on the built-in storage. However, it's strongly recommended to just rely on the built-in storage when possible.
		*/
		public required init(
			for name: Name,
			onChange: ((_ shortcut: Shortcut?) -> Void)? = nil
		) {
			self.shortcutName = name
			self.onChange = onChange

			super.init(frame: .zero)
			self.delegate = self
			self.placeholderString = "Record Shortcut"
			self.centersPlaceholder = true
			self.alignment = .center
			(self.cell as? NSSearchFieldCell)?.searchButtonCell = nil

			self.wantsLayer = true
			self.translatesAutoresizingMaskIntoConstraints = false
			self.setContentHuggingPriority(.defaultHigh, for: .vertical)
			self.setContentHuggingPriority(.defaultHigh, for: .horizontal)
			self.widthAnchor.constraint(greaterThanOrEqualToConstant: CGFloat(minimumWidth)).isActive = true

			// Hide the cancel button when not showing the shortcut so the placeholder text is properly centered. Must be last.
			self.cancelButton = (self.cell as? NSSearchFieldCell)?.cancelButtonCell

			self.setStringValue(name: name)

			setUpEvents()
		}

		@available(*, unavailable)
		public required init?(coder: NSCoder) {
			fatalError("init(coder:) has not been implemented")
		}

		private func setStringValue(name: KeyboardShortcuts.Name) {
			stringValue = getShortcut(for: shortcutName).map { "\($0)" } ?? ""

			// If `stringValue` is empty, hide the cancel button to let the placeholder center.
			showsCancelButton = !stringValue.isEmpty
		}

		private func setUpEvents() {
			observer = NotificationCenter.default.addObserver(forName: .shortcutByNameDidChange, object: nil, queue: nil) { [weak self] notification in
				guard
					let self = self,
					let nameInNotification = notification.userInfo?["name"] as? KeyboardShortcuts.Name,
					nameInNotification == self.shortcutName
				else {
					return
				}

				self.setStringValue(name: nameInNotification)
			}
		}

		/// :nodoc:
		public func controlTextDidChange(_ object: Notification) {
			if stringValue.isEmpty {
				saveShortcut(nil)
			}

			showsCancelButton = !stringValue.isEmpty

			if stringValue.isEmpty {
				// Hack to ensure that the placeholder centers after the above `showsCancelButton` setter.
				focus()
			}
		}

		/// :nodoc:
		public func controlTextDidEndEditing(_ object: Notification) {
			eventMonitor = nil
			placeholderString = "Record Shortcut"
			showsCancelButton = !stringValue.isEmpty
			KeyboardShortcuts.isPaused = false
		}

		/// :nodoc:
		override public func becomeFirstResponder() -> Bool {
			let shouldBecomeFirstResponder = super.becomeFirstResponder()

			guard shouldBecomeFirstResponder else {
				return shouldBecomeFirstResponder
			}

			showsCancelButton = !stringValue.isEmpty
			hideCaret()
			KeyboardShortcuts.isPaused = true // The position here matters.

			eventMonitor = LocalEventMonitor(
                events: [.keyDown, .leftMouseUp, .rightMouseUp]
            ) { [weak self] event in
                
				guard let self = self else {
					return nil
				}

				let clickPoint = self.convert(event.locationInWindow, from: nil)
				let clickMargin: CGFloat = 3

				if event.type == .leftMouseUp || event.type == .rightMouseUp,
                        !self.frame.insetBy(
                            dx: -clickMargin, dy: -clickMargin
                        ).contains(clickPoint)
				{
					self.blur()
					return nil
				}

				guard event.isKeyEvent else {
					return nil
				}

                
                
                if event.modifiers.isEmpty {
                    if event.specialKey == .tab {
                        self.blur()
                        // We intentionally bubble up the event so it can
                        // focus the next responder.
                        return event
                    }
                    if event.keyCode == kVK_Escape {
                        self.blur()
                        return nil
                    }
                    if [.delete, .deleteForward, .backspace]
                            .contains(event.specialKey) {
                        self.clear()
                        return nil
                    }
                }
                
				guard event.modifiers.contains(.command),
                        let shortcut = Shortcut(event: event)
				else {
					NSSound.beep()
                    return nil
				}
                
                // disable shortcuts that can't be converted to SwiftUI
                // `KeyboardShortcut`s.
                if #available(macOS 11.0, *) {
                    if KeyboardShortcut(shortcut) == nil {
                        NSSound.beep()
                        return nil
                    }
                }

                // check if the shortcut has already been registered for
                // another name.
                
//                print("allNames: \(Name.allNames.map(\.rawValue))")
                for name in Name.allNames {
                    if name == self.shortcutName {
//                        print("not checking current shortcut")
                        continue
                    }
                    guard let otherShortcut = getShortcut(for: name) else {
//                        print("no shortcut yet for \(name.rawValue)")
                        continue
                    }
                    if otherShortcut == shortcut {
//                        print("\(otherShortcut) already used for \(name.rawValue)")
                        NSSound.beep()
                        return nil
                    }
                }
                
				self.stringValue = "\(shortcut)"
				self.showsCancelButton = true
				self.saveShortcut(shortcut)
				self.blur()

				return nil
			}.start()

			return shouldBecomeFirstResponder
		}

		private func saveShortcut(_ shortcut: Shortcut?) {
			setShortcut(shortcut, for: shortcutName)
			onChange?(shortcut)
		}
	}
}
