import { Want } from '@kit.AbilityKit'
import { FormExtensionAbility, formBindingData } from '@kit.FormKit'

export default class StudyFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    // The shortcut card intentionally contains no account, transcript or private learning data.
    return formBindingData.createFormBindingData({})
  }
}
