// Value sliders after VentureOS's 2026-11-25 design: an optional step, `committed` when a drag
// ends or a key moves one, the keyboard, and upright sliders that run bottom to top. These run
// without a window, so they drive the view's slider handling directly rather than through input.

import Foundation
@testable import Hudini
import Raylib
import Testing

private func view(_ body: String) throws -> UIView {
    UIView(script: try UIScript(data: Data("""
        <UIScript version="1">
          <Window width="400" height="300"/>
          \(body)
        </UIScript>
        """.utf8)))
}

// A 102-wide track leaves the 10-pixel thumb 90 pixels to travel inside its border.
private let taxes = "<Slider name='taxes' x='0' y='0' width='102' height='10' minValue='0' maxValue='20' step='1'/>"
private let volume = "<Slider name='volume' x='0' y='20' width='102' height='10' minValue='0' maxValue='100'/>"
private let upright = "<Slider name='upright' x='200' y='0' width='10' height='102'/>"

@Test func aStepReadsOnlyOnASliderWithinItsRange() throws {
    let script = try UIScript(data: Data("<UIScript version='1'><Window width='9' height='9'/>\(taxes)</UIScript>".utf8))
    #expect(script.control(named: "taxes")?.step == 1)

    for bad in [
        "<Slider name='a' x='0' y='0' width='9' height='9' step='0'/>",
        "<Slider name='a' x='0' y='0' width='9' height='9' step='-1'/>",
        // The default range is 0 to 1, so a step of 2 can't fit.
        "<Slider name='a' x='0' y='0' width='9' height='9' step='2'/>",
        "<Slider name='a' x='0' y='0' width='9' height='9' minValue='0' maxValue='5' step='6'/>",
        "<ProgressBar name='a' x='0' y='0' width='9' height='9' step='1'/>",
    ] {
        #expect(throws: UIScriptError.invalidStep(owner: "a")) {
            try UIScript(data: Data("<UIScript version='1'><Window width='9' height='9'/>\(bad)</UIScript>".utf8))
        }
    }
    // A step the size of the whole range is allowed: the slider has two values.
    #expect(throws: Never.self) {
        try UIScript(data: Data("<UIScript version='1'><Window width='9' height='9'/><Slider name='a' x='0' y='0' width='9' height='9' step='1'/></UIScript>".utf8))
    }
}

@Test func settingAValueSnapsToTheNearestStepAndReportsNothing() throws {
    let view = try view(taxes + "<Slider name='odd' x='0' y='40' width='102' height='10' maxValue='10' step='3'/>")

    view.setValue(7.4, named: "taxes")
    #expect(view.value(named: "taxes") == 7)
    view.setValue(7.6, named: "taxes")
    #expect(view.value(named: "taxes") == 8)
    view.setValue(99, named: "taxes")
    #expect(view.value(named: "taxes") == 20)
    // 10 isn't a whole number of 3s, so the top is the last step that fits.
    view.setValue(10, named: "odd")
    #expect(view.value(named: "odd") == 9)
}

@Test func draggingReportsOnlyValuesOnAStep() throws {
    let view = try view(taxes)

    #expect(view.beginSliderDrag(at: Vector2(x: 5, y: 5), origin: .zero))
    // Halfway along the 90 pixels the thumb travels.
    #expect(view.dragSlider(to: Vector2(x: 51, y: 5), origin: .zero) == .changed(control: "taxes", value: 10))
    // A pixel further stays on the same step, so it reports nothing.
    #expect(view.dragSlider(to: Vector2(x: 52, y: 5), origin: .zero) == nil)
}

@Test func lettingGoCommitsTheValueItEndedOn() throws {
    let view = try view(volume)

    #expect(view.releaseSlider() == nil)
    #expect(view.beginSliderDrag(at: Vector2(x: 5, y: 25), origin: .zero))
    _ = view.dragSlider(to: Vector2(x: 96, y: 25), origin: .zero)
    #expect(view.releaseSlider() == .committed(control: "volume", value: 100))
    #expect(view.releaseSlider() == nil)

    // A press that doesn't move the value still commits once it's let go.
    #expect(view.beginSliderDrag(at: Vector2(x: 96, y: 25), origin: .zero))
    #expect(view.releaseSlider() == .committed(control: "volume", value: 100))
}

@Test func anUprightSliderRunsBottomToTop() throws {
    let view = try view(upright)

    #expect(view.beginSliderDrag(at: Vector2(x: 205, y: 96), origin: .zero))
    #expect(view.dragSlider(to: Vector2(x: 205, y: 6), origin: .zero) == .changed(control: "upright", value: 1))
    #expect(view.dragSlider(to: Vector2(x: 205, y: 51), origin: .zero) == .changed(control: "upright", value: 0.5))
    #expect(view.dragSlider(to: Vector2(x: 205, y: 500), origin: .zero) == .changed(control: "upright", value: 0))
}

@Test func thePressedSliderTakesTheKeyboard() throws {
    let view = try view(taxes + volume)
    #expect(view.focusedSlider == nil)
    #expect(view.pressSliderKey(.increase).isEmpty)

    #expect(view.beginSliderDrag(at: Vector2(x: 5, y: 5), origin: .zero))
    _ = view.releaseSlider()
    #expect(view.focusedSlider == "taxes")
    #expect(view.pressSliderKey(.increase) == [.changed(control: "taxes", value: 1), .committed(control: "taxes", value: 1)])
    #expect(view.pressSliderKey(.toEnd) == [.changed(control: "taxes", value: 20), .committed(control: "taxes", value: 20)])
    // At an end, the key changes nothing and reports nothing.
    #expect(view.pressSliderKey(.increase).isEmpty)
    #expect(view.pressSliderKey(.toStart) == [.changed(control: "taxes", value: 0), .committed(control: "taxes", value: 0)])

    view.clearFocus()
    #expect(view.focusedSlider == nil)
    #expect(view.pressSliderKey(.toEnd).isEmpty)
}

@Test func withoutAStepAKeyMovesATenthOfTheRange() throws {
    let view = try view(volume)
    #expect(view.beginSliderDrag(at: Vector2(x: 5, y: 25), origin: .zero))
    _ = view.releaseSlider()

    #expect(view.pressSliderKey(.increase) == [.changed(control: "volume", value: 10), .committed(control: "volume", value: 10)])
    #expect(view.pressSliderKey(.decrease) == [.changed(control: "volume", value: 0), .committed(control: "volume", value: 0)])
}

@Test func aDisabledOrHiddenSliderIgnoresKeys() throws {
    let view = try view(taxes)
    #expect(view.beginSliderDrag(at: Vector2(x: 5, y: 5), origin: .zero))
    _ = view.releaseSlider()

    view.setDisabled(true, named: "taxes")
    #expect(view.pressSliderKey(.toEnd).isEmpty)
    view.setDisabled(false, named: "taxes")
    view.setHidden(true, named: "taxes")
    #expect(view.pressSliderKey(.toEnd).isEmpty)
    #expect(view.value(named: "taxes") == 0)
}

@Test func textFieldsAndAreasTakeTheirDocumentsAlignment() throws {
    let view = try view("""
        <TextField name='field' x='0' y='0' width='100' height='20' alignment='center'/>
        <TextArea name='area' x='0' y='30' width='100' height='60' alignment='right'/>
        <TextField name='plain' x='0' y='100' width='100' height='20'/>
        """)

    #expect(view.textField(named: "field")?.alignment == .center)
    #expect(view.textArea(named: "area")?.alignment == .right)
    #expect(view.textField(named: "plain")?.alignment == .left)
}

@Test func alignmentPlacesTextInItsRoom() {
    #expect(UIScript.TextAlignment.left.offset(ofWidth: 40, in: 100) == 0)
    #expect(UIScript.TextAlignment.center.offset(ofWidth: 40, in: 100) == 30)
    #expect(UIScript.TextAlignment.right.offset(ofWidth: 40, in: 100) == 60)
}
