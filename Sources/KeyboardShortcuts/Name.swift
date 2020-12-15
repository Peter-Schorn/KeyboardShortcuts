extension KeyboardShortcuts {
	/**
	The strongly-typed name of the keyboard shortcut.

	After registering it, you can use it in, for example, `KeyboardShortcut.Recorder` and `KeyboardShortcut.onKeyUp()`.

	```
	import KeyboardShortcuts

	extension KeyboardShortcuts.Name {
		static let toggleUnicornMode = Self("toggleUnicornMode")
	}
	```
	*/
	public struct Name: Hashable {
		
        // This makes it possible to use `Shortcut` without the namespace.
		/// :nodoc:
		public typealias Shortcut = KeyboardShortcuts.Shortcut

        /// All of the shortcut names.
        public private(set) static var allNames: Set<Self> = []
        
		public let rawValue: String
		public let defaultShortcut: Shortcut?

		/**
		- Parameter name: Name of the shortcut.
		- Parameter default: Optional default key combination. Do not set this unless it's essential. Users find it annoying when random apps steal their existing keyboard shortcuts. It's generally better to show a welcome screen on the first app launch that lets the user set the shortcut.
		*/
		public init(_ name: String, default defaultShortcut: Shortcut? = nil) {
			self.rawValue = name
			self.defaultShortcut = defaultShortcut
            Self.allNames.insert(self)

			if
				let defaultShortcut = defaultShortcut,
				!userDefaultsContains(name: self)
			{
				setShortcut(defaultShortcut, for: self)
			}
		}
	}
}

extension KeyboardShortcuts.Name: RawRepresentable {
	/// :nodoc:
	public init?(rawValue: String) {
		self.init(rawValue)
	}
}
