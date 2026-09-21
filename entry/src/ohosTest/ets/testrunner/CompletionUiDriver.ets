import { Driver, ON, On } from '@ohos.UiTest'

// Load this module only after AbilityDelegator is initialized.
export function createDriver(): Driver { return Driver.create() }
export function byId(id: string): On { return ON.id(id) }
export function byType(type: string): On { return ON.type(type) }
export function byText(text: string): On { return ON.text(text) }
