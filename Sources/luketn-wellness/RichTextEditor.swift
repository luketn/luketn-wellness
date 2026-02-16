import AppKit
import SwiftUI

struct RichTextEditor: NSViewRepresentable {
    @Binding var text: NSAttributedString
    var isFocused: Bool = false
    var onDropDraggedEntry: ((UUID) -> Bool)? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.scrollerStyle = .overlay

        let textView = DropAwareTextView(frame: .zero)
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        scrollView.documentView = textView

        textView.delegate = context.coordinator
        textView.allowsUndo = true
        textView.isRichText = true
        textView.importsGraphics = false
        textView.usesFindPanel = true
        textView.isContinuousSpellCheckingEnabled = true
        textView.usesAdaptiveColorMappingForDarkAppearance = true
        textView.autoresizingMask = [.width]
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.backgroundColor = .clear
        textView.onDropDraggedEntry = onDropDraggedEntry
        textView.textStorage?.setAttributedString(text)

        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? DropAwareTextView else {
            return
        }

        context.coordinator.textView = textView
        textView.onDropDraggedEntry = onDropDraggedEntry
        if !textView.attributedString().isEqual(to: text) {
            textView.textStorage?.setAttributedString(text)
        }

        if isFocused, textView.window?.firstResponder !== textView {
            textView.window?.makeFirstResponder(textView)
        }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: NSAttributedString
        weak var textView: NSTextView?

        init(text: Binding<NSAttributedString>) {
            _text = text
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            text = textView.attributedString()
        }
    }
}

final class DropAwareTextView: NSTextView {
    var onDropDraggedEntry: ((UUID) -> Bool)?

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        if decodeDraggedID(from: sender.draggingPasteboard) != nil {
            return .move
        }
        return super.draggingEntered(sender)
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        if let draggedID = decodeDraggedID(from: sender.draggingPasteboard) {
            return onDropDraggedEntry?(draggedID) ?? false
        }
        return super.performDragOperation(sender)
    }

    private func decodeDraggedID(from pasteboard: NSPasteboard) -> UUID? {
        guard let value = pasteboard.string(forType: .string) else { return nil }
        return JournalDragToken.decode(value)
    }
}
