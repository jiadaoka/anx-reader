import {
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
  AbilityPluginBinding,
} from '@ohos/flutter_ohos';
import { UIAbility, common } from '@kit.AbilityKit';
import { picker } from '@kit.CoreFileKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';

/** FlutterFileDialogPlugin **/
export default class FlutterFileDialogPlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;
  private abilityBinding: AbilityPluginBinding | null = null;
  private ability: UIAbility | null = null;
  private context: common.UIAbilityContext | null = null;

  constructor() {
  }

  getUniqueClassName(): string {
    return "FlutterFileDialogPlugin"
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), "flutter_file_dialog");
    this.channel.setMethodCallHandler(this)
  }

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    this.abilityBinding = binding;
    this.ability = binding.getAbility();
    this.context = this.ability?.context as common.UIAbilityContext;
  }

  onDetachedFromAbility(): void {
    this.abilityBinding = null;
    this.ability = null;
    this.context = null;
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null)
    }
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    if (call.method == "getPlatformVersion") {
      result.success("OpenHarmony ^ ^ ")
      return;
    }

    if (call.method == "saveFile") {
      this.saveFile(call, result);
      return;
    }

    result.notImplemented()
  }

  private async saveFile(call: MethodCall, result: MethodResult) {
    if (!this.context) {
      result.error("no_context", "UIAbility context is not available", null);
      return;
    }

    if (!call.args) {
      result.error("invalid_arguments", "Missing arguments", null);
      return;
    }

    const args: Map<string, Object> = call.args;
    const sourceFilePath: string | null = args.get("sourceFilePath") as string;
    const data: Uint8Array | null = args.get("data") as Uint8Array;
    const fileNameArg: string | null = args.get("fileName") as string;

    if (!sourceFilePath && !data) {
      result.error("invalid_arguments", "Missing 'sourceFilePath' or 'data'", null);
      return;
    }

    const suggestedName = fileNameArg ?? this.getFileNameFromPath(sourceFilePath);

    const saveOptions = new picker.DocumentSaveOptions();
    if (suggestedName) {
      saveOptions.newFileNames = [suggestedName];
    }

    const documentPicker = new picker.DocumentViewPicker(this.context);

    try {
      const uris: Array<string> = await documentPicker.save(saveOptions);
      if (!uris || uris.length === 0) {
        result.success(null);
        return;
      }

      const targetUri = uris[0];
      await this.writeToUri(targetUri, sourceFilePath, data);
      result.success(targetUri);
    } catch (err) {
      const businessErr = err as BusinessError;
      if (businessErr && (businessErr.code === 201 || businessErr.code === 13900012)) {
        result.success(null);
        return;
      }
      result.error(`${businessErr?.code ?? "save_failed"}`, businessErr?.message ?? "Failed to save file", `${businessErr}`);
    }
  }

  private getFileNameFromPath(path?: string | null): string | null {
    if (!path) {
      return null;
    }
    const lastSlash = path.lastIndexOf("/");
    if (lastSlash < 0 || lastSlash === path.length - 1) {
      return null;
    }
    return path.substring(lastSlash + 1);
  }

  private async writeToUri(targetUri: string, sourceFilePath?: string | null, data?: Uint8Array | null) {
    const destination = fs.openSync(
      targetUri,
      fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC
    );
    try {
      if (sourceFilePath) {
        const source = fs.openSync(sourceFilePath);
        try {
          fs.copyFileSync(source.fd, destination.fd);
        } finally {
          fs.closeSync(source);
        }
      } else if (data) {
        const buffer = data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength);
        fs.writeSync(destination.fd, buffer);
      }
    } finally {
      fs.closeSync(destination);
    }
  }
}
