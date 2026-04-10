# DeviceCommand

Initial placeholder for the provider-agnostic device command contract.

Expected operations:

- `turn_on`
- `turn_off`
- `set_brightness`
- `set_color`
- `get_state`

Future device adapters should conform to this contract rather than inventing provider-specific command flows.
