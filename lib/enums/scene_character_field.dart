/// 角色提示词的七个字段。存库用 [code]，显示名由界面按 locale 取。
enum SceneCharacterField {
  hairColor('hairColor'),
  eyeColor('eyeColor'),
  hairstyle('hairstyle'),
  body('body'),
  age('age'),
  outfit('outfit'),
  marks('marks');

  const SceneCharacterField(this.code);

  final String code;

  static SceneCharacterField? fromCode(String code) {
    for (final field in SceneCharacterField.values) {
      if (field.code == code) return field;
    }
    return null;
  }
}
