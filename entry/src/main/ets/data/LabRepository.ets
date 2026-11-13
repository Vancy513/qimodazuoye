/**
 * 联动实验室 —— 本地持久化层
 *
 * 使用 Preferences 以 JSON 字符串保存设备、规则、日志、环境与场景，
 * 关闭进程后重新打开可完整恢复。
 */
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

export const KEY_DEVICES: string = 'lab_devices';
export const KEY_RULES: string = 'lab_rules';
export const KEY_LOGS: string = 'lab_logs';
export const KEY_ENV: string = 'lab_env';
export const KEY_SCENES: string = 'lab_scenes';

export class LabRepository {
  private store: preferences.Preferences | null = null;
  private lastError: string = '';

  /** 初始化 Preferences 实例，失败时返回 false，界面走降级逻辑 */
  async init(context: common.UIAbilityContext): Promise<boolean> {
    try {
      const options: preferences.Options = { name: 'lab_store' };
      this.store = await preferences.getPreferences(context, options);
      return true;
    } catch (err) {
      this.lastError = 'Preferences 初始化失败';
      return false;
    }
  }

  /** 读取字符串，缺失时返回空字符串 */
  async read(key: string): Promise<string> {
    if (this.store === null) {
      return '';
    }
    try {
      const value: preferences.ValueType = await this.store.get(key, '');
      return value as string;
    } catch (err) {
      this.lastError = '读取 ' + key + ' 失败';
      return '';
    }
  }

  /** 写入并落盘 */
  async write(key: string, value: string): Promise<boolean> {
    if (this.store === null) {
      return false;
    }
    try {
      await this.store.put(key, value);
      await this.store.flush();
      return true;
    } catch (err) {
      this.lastError = '写入 ' + key + ' 失败';
      return false;
    }
  }

  /** 清空全部业务数据，用于「重置演示数据」 */
  async clearAll(): Promise<void> {
    if (this.store === null) {
      return;
    }
    try {
      await this.store.clear();
      await this.store.flush();
    } catch (err) {
      this.lastError = '清空数据失败';
    }
  }

  getLastError(): string {
    return this.lastError;
  }
}
