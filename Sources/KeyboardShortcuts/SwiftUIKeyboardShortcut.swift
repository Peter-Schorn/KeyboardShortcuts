import SwiftUI

@available(macOS 11.0, *)
public extension KeyboardShortcut {
    
    init?(_ shortcut: KeyboardShortcuts.Shortcut) {
        
        let keyEquivalent: KeyEquivalent
        guard let key = shortcut.key else {
            return nil
        }
        switch key {
            case .upArrow:
                keyEquivalent = .upArrow
            case .downArrow:
                keyEquivalent = .downArrow
            case .leftArrow:
                keyEquivalent = .leftArrow
            case .rightArrow:
                keyEquivalent = .rightArrow
            case .escape:
                keyEquivalent = .escape
            case .delete:
                keyEquivalent = .delete
            case .deleteForward:
                keyEquivalent = .deleteForward
            case .home:
                keyEquivalent = .home
            case .end:
                keyEquivalent = .end
            case .pageUp:
                keyEquivalent = .pageUp
            case .pageDown:
                keyEquivalent = .pageDown
            case .keypadClear:
                keyEquivalent = .clear
            case .tab:
                keyEquivalent = .tab
            case .space:
                keyEquivalent = .space
            case .return:
                keyEquivalent = .return
            default:
                if let character = shortcut.keyToCharacter(),
                        character.count == 1 {
                    keyEquivalent = KeyEquivalent(Character(character))
                }
                else {
                    return nil
                }
        }
        self.init(
            keyEquivalent,
            modifiers: shortcut.eventModifiers
        )
    }
    
}

@available(macOS 11.0, *)
public extension KeyboardShortcuts.Shortcut {
    
    /// SwiftUI event modifiers.
    var eventModifiers: EventModifiers {
        return nsModifiersToEventModifiers(self.modifiers)
    }

}

@available(macOS 11.0, *)
public func nsModifiersToEventModifiers(
    _ modifiers: NSEvent.ModifierFlags
) -> EventModifiers {
    
    var eventModifiers: EventModifiers = []
    for modifier in modifiers.elements() {
        switch modifier {
            case .capsLock:
                eventModifiers.insert(.capsLock)
            case .shift:
                eventModifiers.insert(.shift)
            case .control:
                eventModifiers.insert(.control)
            case .option:
                eventModifiers.insert(.option)
            case .command:
                eventModifiers.insert(.command)
            case .numericPad:
                eventModifiers.insert(.numericPad)
            case .function:
                eventModifiers.insert(.function)
            default:
                break
        }
    }
    return eventModifiers
    
}

public extension OptionSet where RawValue: FixedWidthInteger {
    
    func elements() -> AnySequence<Self> {
        var remainingBits = rawValue
        var bitMask: RawValue = 1
        return AnySequence {
            return AnyIterator {
                while remainingBits != 0 {
                    defer { bitMask = bitMask &* 2 }
                    if remainingBits & bitMask != 0 {
                        remainingBits = remainingBits & ~bitMask
                        return Self(rawValue: bitMask)
                    }
                }
                return nil
            }
        }
    }
}

