# iOS keyboard side-wave motion coverage

`selected-option-1-reference.png` is the approved visual direction for the
Voice stage: the activity remains centered, both side waveforms have equal
visual weight, and the keyboard does not add a competing Cancel control.

| Voice phase | Approved behavior | Native implementation |
| --- | --- | --- |
| Ready | Quiet cyan symmetry | Complete static 21-bar silhouette on each side |
| Opening / Starting | Waiting without implying microphone power | Slow cyan opacity sweep with fixed bar heights |
| Listening | More energy around the existing rotating activity | Deterministic cyan height and opacity cycles with a small left/right phase offset |
| Processing | Calmer recognition state | Slower purple edge-to-center height and opacity cycle |
| Reduce Motion | Preserve state without movement | Complete static cyan or purple silhouettes |

The bars are decorative phase indicators, not live audio metering. Their
layout remains bounded around the 128-point regular activity and the 88-point
compact activity, and Quick Insert suspends their animation while the Voice
workspace is hidden.

The implementation and test bundles build successfully for a generic iOS
Simulator destination. Side-by-side runtime comparison with the approved
reference remains a separate Simulator evidence step and must use the actual
keyboard extension in a host field.
