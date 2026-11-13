/**
 * 联动实验室 —— 主界面
 *
 * 页面分为四个工作区：控制台（环境 + 设备）、规则库、执行日志、场景演练。
 * 全部界面状态由本页面持有，业务计算交给 RuleEngine，持久化交给 LabRepository。
 */
import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import {
  AutomationRule, DeviceState, EnvState, EnvMeta, RuleCondition, RuleAction,
  TriggerRecord, ScenePreset, ExecutionResult, DeviceChange, ConflictItem, ExecutionStep,
  ENV_META_LIST, ENV_OCCUPANCY, ENV_TEMP, ENV_HUMIDITY, ENV_LIGHT,
  OP_LIST, readEnv, cloneEnv, cloneRule
} from '../model/LabTypes';
import {
  runRules, validateRule, countMatchedRules, formatRuleSummary,
  formatTime, findDevice
} from '../engine/RuleEngine';
import { createDefaultDevices, createDefaultEnv, createDefaultRules, createDefaultScenes } from '../data/LabDefaults';
import { LabRepository, KEY_DEVICES, KEY_RULES, KEY_LOGS, KEY_ENV, KEY_SCENES } from '../data/LabRepository';

const COLOR_BG: string = '#F1F3F8';
const COLOR_CARD: string = '#FFFFFF';
const COLOR_PRIMARY: string = '#2F6BFF';
const COLOR_PRIMARY_SOFT: string = '#E8EEFF';
const COLOR_TEXT: string = '#1B1F27';
const COLOR_SUB: string = '#6B7280';
const COLOR_LINE: string = '#EAECF0';
const COLOR_OK: string = '#12B76A';
const COLOR_WARN: string = '#F79009';
const COLOR_DANGER: string = '#F04438';
const COLOR_SOFT_BG: string = '#F4F6FA';

interface TabMeta {
  icon: string;
  label: string;
}

const TAB_LIST: TabMeta[] = [
  { icon: '🎛', label: '控制台' },
  { icon: '🧩', label: '规则库' },
  { icon: '📜', label: '日志' },
  { icon: '🏠', label: '场景' }
];

@Entry
@Component
struct Index {
  @State currentTab: number = 0;
  @State devices: DeviceState[] = [];
  @State env: EnvState = { temp: 26, humidity: 50, light: 60, occupancy: 1 };
  @State rules: AutomationRule[] = [];
  @State logs: TriggerRecord[] = [];
  @State scenes: ScenePreset[] = [];
  @State matchedCount: number = 0;
  @State ready: boolean = false;
  @State storeHint: string = '';
  // 规则编辑器状态
  @State showEditor: boolean = false;
  @State editId: string = '';
  @State editName: string = '';
  @State editPriority: number = 3;
  @State editConditions: RuleCondition[] = [];
  @State editActions: RuleAction[] = [];
  @State editError: string = '';
  // 日志展开状态
  @State expandedLogId: string = '';
  private repo: LabRepository = new LabRepository();

  aboutToAppear(): void {
    this.bootstrap();
  }

  /** 冷启动加载：优先读取本地存储，失败或为空时回落到预置 Mock 数据 */
  async bootstrap(): Promise<void> {
    const context = getContext(this) as common.UIAbilityContext;
    const inited: boolean = await this.repo.init(context);
    let devicesText: string = '';
    let rulesText: string = '';
    let logsText: string = '';
    let envText: string = '';
    let scenesText: string = '';
    if (inited) {
      devicesText = await this.repo.read(KEY_DEVICES);
      rulesText = await this.repo.read(KEY_RULES);
      logsText = await this.repo.read(KEY_LOGS);
      envText = await this.repo.read(KEY_ENV);
      scenesText = await this.repo.read(KEY_SCENES);
    } else {
      this.storeHint = '本地存储不可用，本次数据仅在运行期有效';
    }
    this.devices = devicesText.length > 0 ? this.parseDevices(devicesText) : createDefaultDevices();
    this.rules = rulesText.length > 0 ? this.parseRules(rulesText) : createDefaultRules();
    this.logs = logsText.length > 0 ? this.parseLogs(logsText) : [];
    this.env = envText.length > 0 ? this.parseEnv(envText) : createDefaultEnv();
    this.scenes = scenesText.length > 0 ? this.parseScenes(scenesText) : createDefaultScenes();
    this.ready = true;
    this.recalc();
    this.persistAll();
  }

  parseDevices(text: string): DeviceState[] {
    try {
      const list: DeviceState[] = JSON.parse(text) as DeviceState[];
      if (list !== null && list !== undefined && list.length > 0) {
        return list;
      }
    } catch (err) {
      this.storeHint = '设备数据损坏，已恢复默认';
    }
    return createDefaultDevices();
  }

  parseRules(text: string): AutomationRule[] {
    try {
      const list: AutomationRule[] = JSON.parse(text) as AutomationRule[];
      if (list !== null && list !== undefined) {
        return list;
      }
    } catch (err) {
      this.storeHint = '规则数据损坏，已恢复默认';
    }
    return createDefaultRules();
  }

  parseLogs(text: string): TriggerRecord[] {
    try {
      const list: TriggerRecord[] = JSON.parse(text) as TriggerRecord[];
      if (list !== null && list !== undefined) {
        return list;
      }
    } catch (err) {
      this.storeHint = '日志数据损坏，已清空';
    }
    return [];
  }

  parseEnv(text: string): EnvState {
    try {
      const value: EnvState = JSON.parse(text) as EnvState;
      if (value !== null && value !== undefined) {
        return value;
      }
    } catch (err) {
      this.storeHint = '环境数据损坏，已恢复默认';
    }
    return createDefaultEnv();
  }

  parseScenes(text: string): ScenePreset[] {
    try {
      const list: ScenePreset[] = JSON.parse(text) as ScenePreset[];
      if (list !== null && list !== undefined && list.length > 0) {
        return list;
      }
    } catch (err) {
      this.storeHint = '场景数据损坏，已恢复默认';
    }
    return createDefaultScenes();
  }

  /** 统一落盘：设备、规则、日志、环境、场景 */
  async persistAll(): Promise<void> {
    await this.repo.write(KEY_DEVICES, JSON.stringify(this.devices));
    await this.repo.write(KEY_RULES, JSON.stringify(this.rules));
    await this.repo.write(KEY_LOGS, JSON.stringify(this.logs));
    await this.repo.write(KEY_ENV, JSON.stringify(this.env));
    await this.repo.write(KEY_SCENES, JSON.stringify(this.scenes));
  }

  /** 重新统计当前环境下的命中规则数 */
  recalc(): void {
    this.matchedCount = countMatchedRules(this.rules, this.env);
  }

  /** 执行一次联动 */
  runOnce(source: string): void {
    const now: number = Date.now();
    const result: ExecutionResult = runRules(this.rules, this.devices, this.env, now, 'log_' + now);
    this.devices = result.devices;
    const nextLogs: TriggerRecord[] = [result.record];
    for (let i = 0; i < this.logs.length && i < 29; i++) {
      nextLogs.push(this.logs[i]);
    }
    this.logs = nextLogs;
    this.recalc();
    this.persistAll();
    promptAction.showToast({ message: source + '：' + result.record.note });
  }

  /** 修改环境数据并即时刷新命中提示 */
  applyEnvValue(key: string, value: number): void {
    const next: EnvState = cloneEnv(this.env);
    if (key === ENV_TEMP) {
      next.temp = value;
    } else if (key === ENV_HUMIDITY) {
      next.humidity = value;
    } else if (key === ENV_LIGHT) {
      next.light = value;
    } else if (key === ENV_OCCUPANCY) {
      next.occupancy = value >= 1 ? 1 : 0;
    }
    this.env = next;
    this.recalc();
    this.persistAll();
  }

  /** 切换设备开关 */
  toggleDevice(device: DeviceState, isOn: boolean): void {
    const next: DeviceState[] = [];
    for (let i = 0; i < this.devices.length; i++) {
      const item: DeviceState = this.devices[i];
      if (item.id === device.id) {
        next.push({
          id: item.id, name: item.name, type: item.type,
          power: isOn, value: item.value, unit: item.unit, min: item.min, max: item.max
        });
      } else {
        next.push(item);
      }
    }
    this.devices = next;
    this.persistAll();
  }

  /** 调整设备档位 */
  changeDeviceValue(device: DeviceState, value: number): void {
    const next: DeviceState[] = [];
    for (let i = 0; i < this.devices.length; i++) {
      const item: DeviceState = this.devices[i];
      if (item.id === device.id) {
        next.push({
          id: item.id, name: item.name, type: item.type,
          power: item.power, value: value, unit: item.unit, min: item.min, max: item.max
        });
      } else {
        next.push(item);
      }
    }
    this.devices = next;
    this.persistAll();
  }

  /** 启停规则 */
  toggleRule(rule: AutomationRule): void {
    const next: AutomationRule[] = [];
    for (let i = 0; i < this.rules.length; i++) {
      const item: AutomationRule = this.rules[i];
      if (item.id === rule.id) {
        const copy: AutomationRule = cloneRule(item);
        copy.enabled = !item.enabled;
        next.push(copy);
      } else {
        next.push(item);
      }
    }
    this.rules = next;
    this.recalc();
    this.persistAll();
  }

  /** 删除规则 */
  deleteRule(rule: AutomationRule): void {
    const next: AutomationRule[] = [];
    for (let i = 0; i < this.rules.length; i++) {
      if (this.rules[i].id !== rule.id) {
        next.push(this.rules[i]);
      }
    }
    this.rules = next;
    this.recalc();
    this.persistAll();
    promptAction.showToast({ message: '已删除规则「' + rule.name + '」' });
  }

  /** 打开规则编辑器：传 null 表示新建 */
  openEditor(rule: AutomationRule | null): void {
    if (rule === null) {
      this.editId = '';
      this.editName = '';
      this.editPriority = 3;
      this.editConditions = [{ key: ENV_TEMP, op: '>', value: 28 }];
      this.editActions = [{ deviceId: this.devices[0].id, power: true, value: this.devices[0].max }];
    } else {
      const copy: AutomationRule = cloneRule(rule);
      this.editId = copy.id;
      this.editName = copy.name;
      this.editPriority = copy.priority;
      this.editConditions = copy.conditions;
      this.editActions = copy.actions;
    }
    this.editError = '';
    this.showEditor = true;
  }

  closeEditor(): void {
    this.showEditor = false;
    this.editError = '';
  }

  saveDraft(): void {
    const draft: AutomationRule = {
      id: this.editId.length > 0 ? this.editId : 'rule_' + Date.now(),
      name: this.editName.trim(),
      enabled: true,
      priority: this.editPriority,
      conditions: this.editConditions,
      actions: this.editActions
    };
    const errors: string[] = validateRule(draft, this.devices);
    if (errors.length > 0) {
      this.editError = errors[0];
      return;
    }
    let replaced: boolean = false;
    const next: AutomationRule[] = [];
    for (let i = 0; i < this.rules.length; i++) {
      if (this.rules[i].id === draft.id) {
        next.push(draft);
        replaced = true;
      } else {
        next.push(this.rules[i]);
      }
    }
    if (!replaced) {
      next.push(draft);
    }
    this.rules = next;
    this.showEditor = false;
    this.recalc();
    this.persistAll();
    promptAction.showToast({ message: replaced ? '规则已更新' : '规则已创建' });
  }

  /** 应用场景：写入环境数据后立即执行一次联动 */
  applyScene(scene: ScenePreset): void {
    this.env = cloneEnv(scene.env);
    this.recalc();
    this.persistAll();
    this.runOnce('场景「' + scene.name + '」');
  }

  resetDemo(): void {
    this.devices = createDefaultDevices();
    this.rules = createDefaultRules();
    this.env = createDefaultEnv();
    this.scenes = createDefaultScenes();
    this.logs = [];
    this.recalc();
    this.persistAll();
    promptAction.showToast({ message: '已恢复默认演示数据' });
  }

  clearLogs(): void {
    this.logs = [];
    this.expandedLogId = '';
    this.persistAll();
  }

  metaOf(key: string): EnvMeta {
    for (let i = 0; i < ENV_META_LIST.length; i++) {
      if (ENV_META_LIST[i].key === key) {
        return ENV_META_LIST[i];
      }
    }
    return ENV_META_LIST[0];
  }

  deviceIcon(type: string): string {
    if (type === 'light') {
      return '💡';
    }
    if (type === 'ac') {
      return '❄️';
    }
    if (type === 'curtain') {
      return '🪟';
    }
    return '💧';
  }

  deviceStateText(device: DeviceState): string {
    if (!device.power) {
      return '已关闭';
    }
    return '开启 · ' + device.value + device.unit;
  }

  envSummary(env: EnvState): string {
    return env.temp + '℃ · 湿度' + env.humidity + '% · 光照' + env.light + '% · ' +
      (env.occupancy >= 1 ? '有人' : '无人');
  }

  enabledCount(): number {
    let count: number = 0;
    for (let i = 0; i < this.rules.length; i++) {
      if (this.rules[i].enabled) {
        count++;
      }
    }
    return count;
  }

  updateCondition(index: number, key: string, op: string, value: number): void {
    const next: RuleCondition[] = [];
    for (let i = 0; i < this.editConditions.length; i++) {
      const item: RuleCondition = this.editConditions[i];
      if (i === index) {
        next.push({ key: key, op: op, value: value });
      } else {
        next.push({ key: item.key, op: item.op, value: item.value });
      }
    }
    this.editConditions = next;
  }

  addCondition(): void {
    if (this.editConditions.length >= 2) {
      return;
    }
    const next: RuleCondition[] = [];
    for (let i = 0; i < this.editConditions.length; i++) {
      next.push(this.editConditions[i]);
    }
    next.push({ key: ENV_OCCUPANCY, op: '==', value: 1 });
    this.editConditions = next;
  }

  removeCondition(index: number): void {
    const next: RuleCondition[] = [];
    for (let i = 0; i < this.editConditions.length; i++) {
      if (i !== index) {
        next.push(this.editConditions[i]);
      }
    }
    this.editConditions = next;
  }

  updateAction(index: number, deviceId: string, power: boolean, value: number): void {
    const next: RuleAction[] = [];
    for (let i = 0; i < this.editActions.length; i++) {
      const item: RuleAction = this.editActions[i];
      if (i === index) {
        next.push({ deviceId: deviceId, power: power, value: value });
      } else {
        next.push({ deviceId: item.deviceId, power: item.power, value: item.value });
      }
    }
    this.editActions = next;
  }

  addAction(): void {
    if (this.editActions.length >= 2) {
      return;
    }
    const next: RuleAction[] = [];
    for (let i = 0; i < this.editActions.length; i++) {
      next.push(this.editActions[i]);
    }
    next.push({ deviceId: this.devices[1].id, power: true, value: this.devices[1].min });
    this.editActions = next;
  }

  removeAction(index: number): void {
    const next: RuleAction[] = [];
    for (let i = 0; i < this.editActions.length; i++) {
      if (i !== index) {
        next.push(this.editActions[i]);
      }
    }
    this.editActions = next;
  }

  /* ================= 页面结构 ================= */

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column() {
        this.HeaderBar()
        if (this.currentTab === 0) {
          this.ConsoleTab()
        } else if (this.currentTab === 1) {
          this.RulesTab()
        } else if (this.currentTab === 2) {
          this.LogsTab()
        } else {
          this.ScenesTab()
        }
        this.BottomBar()
      }
      .width('100%')
      .height('100%')

      if (this.showEditor) {
        this.EditorOverlay()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_BG)
  }

  @Builder HeaderBar() {
    Row() {
      Column({ space: 2 }) {
        Text('联动实验室')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_TEXT)
        Text('智能宿舍 · 条件触发 · 设备联动')
          .fontSize(12)
          .fontColor(COLOR_SUB)
      }
      .alignItems(HorizontalAlign.Start)

      Blank()

      Column({ space: 2 }) {
        Text('命中 ' + this.matchedCount + ' 条')
          .fontSize(11)
          .fontColor(COLOR_PRIMARY)
        Text(this.env.occupancy >= 1 ? '有人在宿舍' : '宿舍无人')
          .fontSize(11)
          .fontColor(COLOR_SUB)
      }
      .alignItems(HorizontalAlign.End)
      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
      .backgroundColor(COLOR_PRIMARY_SOFT)
      .borderRadius(12)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 12 })
  }

  @Builder BottomBar() {
    Row() {
      ForEach(TAB_LIST, (item: TabMeta, index: number) => {
        Column({ space: 2 }) {
          Text(item.icon)
            .fontSize(18)
            .opacity(this.currentTab === index ? 1 : 0.45)
          Text(item.label)
            .fontSize(11)
            .fontColor(this.currentTab === index ? COLOR_PRIMARY : COLOR_SUB)
        }
        .layoutWeight(1)
        .padding({ top: 8, bottom: 8 })
        .onClick(() => {
          this.currentTab = index;
        })
      }, (item: TabMeta) => item.label)
    }
    .width('100%')
    .backgroundColor(COLOR_CARD)
    .border({ width: { top: 0.5 }, color: COLOR_LINE })
  }

  /* ================= 控制台 ================= */

  @Builder ConsoleTab() {
    Scroll() {
      Column({ space: 14 }) {
        if (this.storeHint.length > 0) {
          Text('⚠ ' + this.storeHint)
            .fontSize(11)
            .fontColor(COLOR_WARN)
            .width('100%')
            .padding(10)
            .backgroundColor('#FFF7E8')
            .borderRadius(10)
        }
        this.EnvCard()
        this.DeviceSection()
        this.RunPanel()
        this.LastResultCard()
      }
      .padding({ left: 16, right: 16, top: 4, bottom: 24 })
    }
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
  }

  @Builder EnvCard() {
    Column({ space: 10 }) {
      Row() {
        Text('模拟环境')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_TEXT)
        Blank()
        Text('拖动即时预览命中')
          .fontSize(11)
          .fontColor(COLOR_SUB)
      }
      .width('100%')

      ForEach(ENV_META_LIST, (meta: EnvMeta) => {
        if (meta.key === ENV_OCCUPANCY) {
          Row() {
            Text('👥 人员状态')
              .fontSize(13)
              .fontColor(COLOR_TEXT)
            Blank()
            Text(this.env.occupancy >= 1 ? '有人' : '无人')
              .fontSize(13)
              .fontColor(this.env.occupancy >= 1 ? COLOR_PRIMARY : COLOR_SUB)
              .margin({ right: 8 })
            Toggle({ type: ToggleType.Switch, isOn: this.env.occupancy >= 1 })
              .onChange((isOn: boolean) => {
                this.applyEnvValue(ENV_OCCUPANCY, isOn ? 1 : 0);
              })
          }
          .width('100%')
          .height(38)
        } else {
          Column() {
            Row() {
              Text(meta.label)
                .fontSize(13)
                .fontColor(COLOR_TEXT)
              Blank()
              Text(readEnv(this.env, meta.key) + meta.unit)
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(COLOR_PRIMARY)
            }
            .width('100%')

            Slider({
              value: readEnv(this.env, meta.key),
              min: meta.min,
              max: meta.max,
              step: 1,
              style: SliderStyle.OutSet
            })
              .width('100%')
              .selectedColor(COLOR_PRIMARY)
              .trackColor(COLOR_SOFT_BG)
              .blockColor(COLOR_CARD)
              .onChange((value: number) => {
                this.applyEnvValue(meta.key, value);
              })
          }
          .width('100%')
        }
      }, (meta: EnvMeta) => meta.key)
    }
    .width('100%')
    .padding(14)
    .backgroundColor(COLOR_CARD)
    .borderRadius(18)
  }

  @Builder DeviceSection() {
    Column({ space: 10 }) {
      Row() {
        Text('可控设备')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(COLOR_TEXT)
        Blank()
        Text('共 ' + this.devices.length + ' 类')
          .fontSize(11)
          .fontColor(COLOR_SUB)
      }
      .width('100%')

      Row({ space: 10 }) {
        ForEach(this.devices.slice(0, 2), (device: DeviceState) => {
          this.DeviceCard(device)
        }, (device: DeviceState) => device.id + '_' + device.power + '_' + device.value)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Row({ space: 10 }) {
        ForEach(this.devices.slice(2, 4), (device: DeviceState) => {
          this.DeviceCard(device)
        }, (device: DeviceState) => device.id + '_' + device.power + '_' + device.value)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
  }

  @Builder DeviceCard(device: DeviceState) {
    Column({ space: 6 }) {
      Row() {
        Text(this.deviceIcon(device.type))
          .fontSize(20)
        Blank()
        Toggle({ type: ToggleType.Switch, isOn: device.power })
          .onChange((isOn: boolean) => {
            this.toggleDevice(device, isOn);
          })
      }
      .width('100%')

      Text(device.name)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor(COLOR_TEXT)
        .width('100%')

      Text(this.deviceStateText(device))
        .fontSize(11)
        .fontColor(device.power ? COLOR_PRIMARY : COLOR_SUB)
        .width('100%')

      Slider({
        value: device.value,
        min: device.min,
        max: device.max,
        step: 1,
        style: SliderStyle.OutSet
      })
        .width('100%')
        .selectedColor(device.power ? COLOR_PRIMARY : COLOR_LINE)
        .trackColor(COLOR_SOFT_BG)
        .blockColor(COLOR_CARD)
        .onChange((value: number) => {
          this.changeDeviceValue(device, value);
        })
    }
    .layoutWeight(1)
    .padding(12)
    .backgroundColor(COLOR_CARD)
    .borderRadius(18)
    .border({ width: device.power ? 1.5 : 1, color: device.power ? COLOR_PRIMARY : COLOR_LINE })
  }

  @Builder RunPanel() {
    Column({ space: 8 }) {
      Button({ type: ButtonType.Normal }) {
        Row({ space: 8 }) {
          Text('⚡')
            .fontSize(18)
          Text('运行联动')
            .fontSize(16)
            .fontColor(Color.White)
        }
      }
      .width('100%')
      .height(50)
      .backgroundColor(COLOR_PRIMARY)
      .borderRadius(16)
      .onClick(() => {
        this.runOnce('手动执行');
      })

      Text('按优先级依次判定规则并控制设备，结果写入执行日志')
        .fontSize(11)
        .fontColor(COLOR_SUB)
        .width('100%')
        .textAlign(TextAlign.Center)
    }
    .width('100%')
  }

  @Builder LastResultCard() {
    Column({ space: 8 }) {
      Row() {
        Text('最近一次执行')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_TEXT)
        Blank()
        if (this.logs.length > 0) {
          Text(formatTime(this.logs[0].time))
            .fontSize(11)
            .fontColor(COLOR_SUB)
        }
      }
      .width('100%')

      if (this.logs.length === 0) {
        Text('还没有执行记录，先调整环境再点击「运行联动」')
          .fontSize(12)
          .fontColor(COLOR_SUB)
          .width('100%')
      } else {
        Text(this.logs[0].note)
          .fontSize(12)
          .fontColor(COLOR_TEXT)
          .width('100%')
        Row({ space: 6 }) {
          ForEach(this.logs[0].changes, (change: DeviceChange) => {
            Text(change.deviceName + ' ' + (change.afterPower ? 'ON' : 'OFF'))
              .fontSize(10)
              .fontColor(COLOR_PRIMARY)
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .backgroundColor(COLOR_PRIMARY_SOFT)
              .borderRadius(8)
          }, (change: DeviceChange) => change.deviceId + '_' + change.afterPower)
        }
        .width('100%')

        if (this.logs[0].conflicts.length > 0) {
          Text('冲突 ' + this.logs[0].conflicts.length + ' 处，已按优先级处理')
            .fontSize(11)
            .fontColor(COLOR_WARN)
            .width('100%')
        }
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor(COLOR_CARD)
    .borderRadius(18)
  }

  /* ================= 规则库 ================= */

  @Builder RulesTab() {
    Column({ space: 10 }) {
      Row() {
        Column({ space: 2 }) {
          Text('规则库')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_TEXT)
          Text('共 ' + this.rules.length + ' 条 · 启用 ' + this.enabledCount() + ' 条')
            .fontSize(11)
            .fontColor(COLOR_SUB)
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Text('+ 新建规则')
          .fontSize(12)
          .fontColor(Color.White)
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .backgroundColor(COLOR_PRIMARY)
          .borderRadius(12)
          .onClick(() => {
            this.openEditor(null);
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 4 })

      Scroll() {
        Column({ space: 10 }) {
          if (this.rules.length === 0) {
            Column({ space: 6 }) {
              Text('还没有规则')
                .fontSize(14)
                .fontColor(COLOR_TEXT)
              Text('点击右上角「新建规则」创建第一条联动')
                .fontSize(12)
                .fontColor(COLOR_SUB)
            }
            .width('100%')
            .padding(30)
            .backgroundColor(COLOR_CARD)
            .borderRadius(16)
          }
          ForEach(this.rules, (rule: AutomationRule) => {
            this.RuleCard(rule)
          }, (rule: AutomationRule) => JSON.stringify(rule))
        }
        .padding({ left: 16, right: 16, top: 4, bottom: 24 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder RuleCard(rule: AutomationRule) {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text(rule.name)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_TEXT)
        Text('P' + rule.priority)
          .fontSize(10)
          .fontColor(COLOR_PRIMARY)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .backgroundColor(COLOR_PRIMARY_SOFT)
          .borderRadius(6)
        if (!rule.enabled) {
          Text('已停用')
            .fontSize(10)
            .fontColor(COLOR_SUB)
        }
        Blank()
        Toggle({ type: ToggleType.Switch, isOn: rule.enabled })
          .onChange((isOn: boolean) => {
            this.toggleRule(rule);
          })
      }
      .width('100%')

      Text(formatRuleSummary(rule, this.devices))
        .fontSize(12)
        .fontColor(COLOR_SUB)
        .width('100%')

      Row({ space: 16 }) {
        Text('编辑')
          .fontSize(12)
          .fontColor(COLOR_PRIMARY)
          .onClick(() => {
            this.openEditor(rule);
          })
        Text('删除')
          .fontSize(12)
          .fontColor(COLOR_DANGER)
          .onClick(() => {
            this.deleteRule(rule);
          })
        Blank()
        Text(rule.conditions.length > 1 ? '双条件规则' : '单条件规则')
          .fontSize(10)
          .fontColor(COLOR_SUB)
      }
      .width('100%')
    }
    .width('100%')
    .padding(14)
    .backgroundColor(COLOR_CARD)
    .borderRadius(16)
    .opacity(rule.enabled ? 1 : 0.6)
  }

  /* ================= 执行日志 ================= */

  @Builder LogsTab() {
    Column({ space: 10 }) {
      Row() {
        Column({ space: 2 }) {
          Text('执行日志')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_TEXT)
          Text('最近 ' + this.logs.length + ' 次联动（最多保留 30 条）')
            .fontSize(11)
            .fontColor(COLOR_SUB)
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Text('清空')
          .fontSize(12)
          .fontColor(COLOR_SUB)
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .backgroundColor(COLOR_CARD)
          .borderRadius(12)
          .onClick(() => {
            this.clearLogs();
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 4 })

      Scroll() {
        Column({ space: 10 }) {
          if (this.logs.length === 0) {
            Column({ space: 6 }) {
              Text('暂无执行记录')
                .fontSize(14)
                .fontColor(COLOR_TEXT)
              Text('去控制台点击「运行联动」，或到场景页一键演练')
                .fontSize(12)
                .fontColor(COLOR_SUB)
            }
            .width('100%')
            .padding(30)
            .backgroundColor(COLOR_CARD)
            .borderRadius(16)
          }
          ForEach(this.logs, (record: TriggerRecord) => {
            this.LogCard(record)
          }, (record: TriggerRecord) => record.id)
        }
        .padding({ left: 16, right: 16, top: 4, bottom: 24 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder LogCard(record: TriggerRecord) {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text(formatTime(record.time))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_TEXT)
        Text(record.matchedRules.length + ' 条规则')
          .fontSize(10)
          .fontColor(COLOR_PRIMARY)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .backgroundColor(COLOR_PRIMARY_SOFT)
          .borderRadius(6)
        Blank()
        if (record.conflicts.length > 0) {
          Text('含冲突')
            .fontSize(10)
            .fontColor(COLOR_WARN)
        }
        Text(this.expandedLogId === record.id ? '收起' : '详情')
          .fontSize(11)
          .fontColor(COLOR_PRIMARY)
      }
      .width('100%')
      .onClick(() => {
        this.expandedLogId = this.expandedLogId === record.id ? '' : record.id;
      })

      Text(record.note)
        .fontSize(12)
        .fontColor(COLOR_SUB)
        .width('100%')

      if (this.expandedLogId === record.id) {
        Divider()
          .color(COLOR_LINE)

        Text('环境快照：' + this.envSummary(record.env))
          .fontSize(11)
          .fontColor(COLOR_TEXT)
          .width('100%')

        if (record.steps.length > 0) {
          Text('执行顺序')
            .fontSize(11)
            .fontColor(COLOR_SUB)
            .width('100%')
            .margin({ top: 4 })
          ForEach(record.steps, (step: ExecutionStep) => {
            Row({ space: 6 }) {
              Text('' + step.order)
                .fontSize(10)
                .fontColor(Color.White)
                .width(16)
                .height(16)
                .textAlign(TextAlign.Center)
                .backgroundColor(COLOR_PRIMARY)
                .borderRadius(8)
              Text(step.ruleName + ' → ' + step.deviceName + ' ' +
                (step.targetPower ? '开启 ' + step.targetValue : '关闭'))
                .fontSize(11)
                .fontColor(COLOR_TEXT)
                .layoutWeight(1)
            }
            .width('100%')
          }, (step: ExecutionStep) => record.id + '_' + step.order)
        }

        if (record.conflicts.length > 0) {
          Text('冲突处理')
            .fontSize(11)
            .fontColor(COLOR_WARN)
            .width('100%')
            .margin({ top: 4 })
          ForEach(record.conflicts, (conflict: ConflictItem) => {
            Text(conflict.deviceName + '：' + conflict.winnerRuleName +
              ' 优先级更高，' + conflict.skippedRuleName + ' 被跳过')
              .fontSize(11)
              .fontColor(COLOR_WARN)
              .width('100%')
          }, (conflict: ConflictItem) => record.id + '_' + conflict.skippedRuleId)
        }
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor(COLOR_CARD)
    .borderRadius(16)
  }

  /* ================= 场景演练 ================= */

  @Builder ScenesTab() {
    Scroll() {
      Column({ space: 12 }) {
        Column({ space: 2 }) {
          Text('场景演练')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_TEXT)
            .width('100%')
          Text('一键切换模拟环境并立即执行联动，用于对比不同场景下的设备表现')
            .fontSize(11)
            .fontColor(COLOR_SUB)
            .width('100%')
        }
        .padding({ top: 4 })

        ForEach(this.scenes, (scene: ScenePreset) => {
          this.SceneCard(scene)
        }, (scene: ScenePreset) => scene.id)

        Column({ space: 6 }) {
          Text('冲突处理规则')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(COLOR_TEXT)
            .width('100%')
          Text('① 优先级数值大的规则先执行；② 优先级相同时按规则列表顺序执行；' +
            '③ 同一台设备在一轮联动中只接受一次控制，被压制的规则会写入「冲突处理」日志。')
            .fontSize(11)
            .fontColor(COLOR_SUB)
            .width('100%')
            .lineHeight(18)
        }
        .width('100%')
        .padding(14)
        .backgroundColor(COLOR_CARD)
        .borderRadius(16)

        Button('恢复默认演示数据')
          .width('100%')
          .height(44)
          .backgroundColor(COLOR_CARD)
          .fontColor(COLOR_DANGER)
          .fontSize(13)
          .borderRadius(12)
          .onClick(() => {
            this.resetDemo();
          })
      }
      .padding({ left: 16, right: 16, top: 4, bottom: 24 })
    }
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .align(Alignment.Top)
  }

  @Builder SceneCard(scene: ScenePreset) {
    Column({ space: 8 }) {
      Row() {
        Text(scene.name)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(COLOR_TEXT)
        Blank()
        Text('应用')
          .fontSize(12)
          .fontColor(Color.White)
          .padding({ left: 14, right: 14, top: 6, bottom: 6 })
          .backgroundColor(COLOR_PRIMARY)
          .borderRadius(10)
          .onClick(() => {
            this.applyScene(scene);
          })
      }
      .width('100%')

      Text(scene.desc)
        .fontSize(11)
        .fontColor(COLOR_SUB)
        .width('100%')

      Row({ space: 6 }) {
        Text(scene.env.temp + '℃')
          .fontSize(10)
          .fontColor(COLOR_TEXT)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor(COLOR_SOFT_BG)
          .borderRadius(6)
        Text('湿度' + scene.env.humidity + '%')
          .fontSize(10)
          .fontColor(COLOR_TEXT)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor(COLOR_SOFT_BG)
          .borderRadius(6)
        Text('光照' + scene.env.light + '%')
          .fontSize(10)
          .fontColor(COLOR_TEXT)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor(COLOR_SOFT_BG)
          .borderRadius(6)
        Text(scene.env.occupancy >= 1 ? '有人' : '无人')
          .fontSize(10)
          .fontColor(COLOR_TEXT)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor(COLOR_SOFT_BG)
          .borderRadius(6)
      }
      .width('100%')
    }
    .width('100%')
    .padding(14)
    .backgroundColor(COLOR_CARD)
    .borderRadius(16)
  }

  /* ================= 规则编辑器 ================= */

  @Builder ChoiceChip(label: string, selected: boolean, onTap: () => void) {
    Text(label)
      .fontSize(11)
      .fontColor(selected ? Color.White : COLOR_TEXT)
      .backgroundColor(selected ? COLOR_PRIMARY : COLOR_SOFT_BG)
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      .borderRadius(8)
      .margin({ right: 6 })
      .onClick(onTap)
  }

  @Builder ConditionEditor(condition: RuleCondition, index: number) {
    Column({ space: 8 }) {
      Row({ space: 0 }) {
        ForEach(ENV_META_LIST, (meta: EnvMeta) => {
          this.ChoiceChip(meta.label, condition.key === meta.key, () => {
            this.updateCondition(index, meta.key, condition.op, this.metaOf(meta.key).min);
          });
        }, (meta: EnvMeta) => 'env_' + meta.key)
      }
      .width('100%')

      Row({ space: 0 }) {
        ForEach(OP_LIST, (op: string) => {
          this.ChoiceChip(op, condition.op === op, () => {
            this.updateCondition(index, condition.key, op, condition.value);
          });
        }, (op: string) => 'op_' + op)
        Blank()
        if (this.editConditions.length > 1) {
          Text('删除')
            .fontSize(11)
            .fontColor(COLOR_DANGER)
            .onClick(() => {
              this.removeCondition(index);
            })
        }
      }
      .width('100%')

      Row({ space: 8 }) {
        if (condition.key === ENV_OCCUPANCY) {
          Text(condition.value >= 1 ? '有人' : '无人')
            .fontSize(12)
            .fontColor(COLOR_TEXT)
            .width(48)
        } else {
          Text(condition.value + this.metaOf(condition.key).unit)
            .fontSize(12)
            .fontColor(COLOR_TEXT)
            .width(48)
        }
        Slider({
          value: condition.value,
          min: this.metaOf(condition.key).min,
          max: this.metaOf(condition.key).max,
          step: 1,
          style: SliderStyle.OutSet
        })
          .layoutWeight(1)
          .selectedColor(COLOR_PRIMARY)
          .trackColor(COLOR_SOFT_BG)
          .blockColor(COLOR_CARD)
          .onChange((value: number) => {
            this.updateCondition(index, condition.key, condition.op, value);
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(10)
    .backgroundColor(COLOR_SOFT_BG)
    .borderRadius(12)
  }

  targetDeviceText(action: RuleAction): string {
    const device: DeviceState | null = findDevice(this.devices, action.deviceId);
    if (device === null) {
      return '设备不存在';
    }
    return device.name + ' 目标 ' + (action.power ? '开启 ' : '关闭 ') + action.value + device.unit;
  }

  actionMin(action: RuleAction): number {
    const device: DeviceState | null = findDevice(this.devices, action.deviceId);
    return device === null ? 0 : device.min;
  }

  actionMax(action: RuleAction): number {
    const device: DeviceState | null = findDevice(this.devices, action.deviceId);
    return device === null ? 100 : device.max;
  }

  @Builder ActionEditor(action: RuleAction, index: number) {
    Column({ space: 8 }) {
      Row({ space: 0 }) {
        ForEach(this.devices, (device: DeviceState) => {
          this.ChoiceChip(device.name, action.deviceId === device.id, () => {
            this.updateAction(index, device.id, action.power, device.min);
          });
        }, (device: DeviceState) => 'act_' + device.id)
        Blank()
        if (this.editActions.length > 1) {
          Text('删除')
            .fontSize(11)
            .fontColor(COLOR_DANGER)
            .onClick(() => {
              this.removeAction(index);
            })
        }
      }
      .width('100%')

      Row({ space: 0 }) {
        this.ChoiceChip('开启', action.power, () => {
          this.updateAction(index, action.deviceId, true, action.value);
        });
        this.ChoiceChip('关闭', !action.power, () => {
          this.updateAction(index, action.deviceId, false, action.value);
        });
        Blank()
        Text(this.targetDeviceText(action))
          .fontSize(10)
          .fontColor(COLOR_SUB)
      }
      .width('100%')

      Row({ space: 8 }) {
        Text('' + action.value)
          .fontSize(12)
          .fontColor(COLOR_TEXT)
          .width(48)
        Slider({
          value: action.value,
          min: this.actionMin(action),
          max: this.actionMax(action),
          step: 1,
          style: SliderStyle.OutSet
        })
          .layoutWeight(1)
          .selectedColor(COLOR_PRIMARY)
          .trackColor(COLOR_SOFT_BG)
          .blockColor(COLOR_CARD)
          .onChange((value: number) => {
            this.updateAction(index, action.deviceId, action.power, value);
          })
      }
      .width('100%')
    }
    .width('100%')
    .padding(10)
    .backgroundColor(COLOR_SOFT_BG)
    .borderRadius(12)
  }

  @Builder EditorOverlay() {
    Column() {
      Column({ space: 12 }) {
        Row() {
          Text(this.editId.length > 0 ? '编辑规则' : '新建规则')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(COLOR_TEXT)
          Blank()
          Text('✕')
            .fontSize(16)
            .fontColor(COLOR_SUB)
            .onClick(() => {
              this.closeEditor();
            })
        }
        .width('100%')

        TextInput({ text: this.editName, placeholder: '规则名称，例如：高温开空调' })
          .width('100%')
          .height(42)
          .borderRadius(10)
          .backgroundColor(COLOR_SOFT_BG)
          .onChange((value: string) => {
            this.editName = value;
          })

        Row({ space: 8 }) {
          Text('优先级')
            .fontSize(12)
            .fontColor(COLOR_SUB)
          ForEach([1, 2, 3, 4, 5], (level: number) => {
            Text('' + level)
              .fontSize(12)
              .fontColor(this.editPriority === level ? Color.White : COLOR_TEXT)
              .width(30)
              .height(28)
              .textAlign(TextAlign.Center)
              .backgroundColor(this.editPriority === level ? COLOR_PRIMARY : COLOR_SOFT_BG)
              .borderRadius(8)
              .onClick(() => {
                this.editPriority = level;
              })
          }, (level: number) => 'level_' + level)
        }
        .width('100%')

        Scroll() {
          Column({ space: 10 }) {
            Row() {
              Text('触发条件（多个条件同时满足才触发）')
                .fontSize(12)
                .fontColor(COLOR_SUB)
              Blank()
              if (this.editConditions.length < 2) {
                Text('+ 添加条件')
                  .fontSize(11)
                  .fontColor(COLOR_PRIMARY)
                  .onClick(() => {
                    this.addCondition();
                  })
              }
            }
            .width('100%')

            ForEach(this.editConditions, (condition: RuleCondition, index: number) => {
              this.ConditionEditor(condition, index)
            }, (condition: RuleCondition, index: number) => 'cond_' + index + '_' +
              condition.key + condition.op + condition.value)

            Row() {
              Text('设备动作（按顺序执行）')
                .fontSize(12)
                .fontColor(COLOR_SUB)
              Blank()
              if (this.editActions.length < 2) {
                Text('+ 添加动作')
                  .fontSize(11)
                  .fontColor(COLOR_PRIMARY)
                  .onClick(() => {
                    this.addAction();
                  })
              }
            }
            .width('100%')

            ForEach(this.editActions, (action: RuleAction, index: number) => {
              this.ActionEditor(action, index)
            }, (action: RuleAction, index: number) => 'action_' + index + '_' +
              action.deviceId + action.power + action.value)
          }
          .width('100%')
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .align(Alignment.Top)

        if (this.editError.length > 0) {
          Text('⚠ ' + this.editError)
            .fontSize(11)
            .fontColor(COLOR_DANGER)
            .width('100%')
        }

        Row({ space: 10 }) {
          Button('取消')
            .layoutWeight(1)
            .height(44)
            .backgroundColor(COLOR_SOFT_BG)
            .fontColor(COLOR_TEXT)
            .fontSize(14)
            .borderRadius(12)
            .onClick(() => {
              this.closeEditor();
            })
          Button('保存规则')
            .layoutWeight(1)
            .height(44)
            .backgroundColor(COLOR_PRIMARY)
            .fontColor(Color.White)
            .fontSize(14)
            .borderRadius(12)
            .onClick(() => {
              this.saveDraft();
            })
        }
        .width('100%')
      }
      .width('92%')
      .height('84%')
      .padding(16)
      .backgroundColor(COLOR_CARD)
      .borderRadius(22)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#66000000')
    .justifyContent(FlexAlign.Center)
  }
}
