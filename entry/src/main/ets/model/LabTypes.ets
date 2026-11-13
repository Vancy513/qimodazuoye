/**
 * 联动实验室 —— 领域数据模型
 *
 * 本文件只包含纯数据结构与常量，不依赖任何 @ohos 能力，
 * 因此可以被规则引擎、界面层与本地单元测试同时引用。
 */

/** 环境数据键：温度 */
export const ENV_TEMP: string = 'temp';
/** 环境数据键：湿度 */
export const ENV_HUMIDITY: string = 'humidity';
/** 环境数据键：光照 */
export const ENV_LIGHT: string = 'light';
/** 环境数据键：人员状态（0 无人 / 1 有人） */
export const ENV_OCCUPANCY: string = 'occupancy';

/** 比较运算符 */
export const OP_GT: string = '>';
export const OP_GTE: string = '>=';
export const OP_LT: string = '<';
export const OP_LTE: string = '<=';
export const OP_EQ: string = '==';

/** 设备类型 */
export const DEV_LIGHT: string = 'light';
export const DEV_AC: string = 'ac';
export const DEV_CURTAIN: string = 'curtain';
export const DEV_HUMIDIFIER: string = 'humidifier';

/** 环境快照：模拟宿舍的 4 项环境数据 */
export interface EnvState {
  /** 温度，单位 ℃，范围 16~35 */
  temp: number;
  /** 相对湿度，单位 %，范围 20~95 */
  humidity: number;
  /** 光照强度，单位 %，范围 0~100 */
  light: number;
  /** 人员状态，1 表示有人、0 表示无人 */
  occupancy: number;
}

/** 可控设备状态 */
export interface DeviceState {
  /** 设备唯一标识 */
  id: string;
  /** 设备名称 */
  name: string;
  /** 设备类型，取 DEV_* 常量 */
  type: string;
  /** 是否开启 */
  power: boolean;
  /** 档位/数值：灯为亮度 %、空调为温度 ℃、窗帘为开合 %、加湿器为湿度 % */
  value: number;
  /** 数值单位 */
  unit: string;
  /** 可调下界 */
  min: number;
  /** 可调上界 */
  max: number;
}

/** 规则条件：环境键 + 比较符 + 阈值 */
export interface RuleCondition {
  key: string;
  op: string;
  value: number;
}

/** 规则动作：对某台设备的目标状态 */
export interface RuleAction {
  deviceId: string;
  power: boolean;
  value: number;
}

/** 自动化规则 */
export interface AutomationRule {
  id: string;
  name: string;
  /** 是否启用 */
  enabled: boolean;
  /** 优先级，数值越大越优先，相同优先级按列表顺序 */
  priority: number;
  /** 条件集合，多个条件为「与」关系 */
  conditions: RuleCondition[];
  actions: RuleAction[];
}

/** 一次设备变化记录 */
export interface DeviceChange {
  deviceId: string;
  deviceName: string;
  beforePower: boolean;
  afterPower: boolean;
  beforeValue: number;
  afterValue: number;
}

/** 冲突记录：低优先级规则被高优先级规则压制 */
export interface ConflictItem {
  deviceId: string;
  deviceName: string;
  winnerRuleId: string;
  winnerRuleName: string;
  skippedRuleId: string;
  skippedRuleName: string;
}

/** 单步执行记录，用于展示「执行顺序」 */
export interface ExecutionStep {
  order: number;
  ruleId: string;
  ruleName: string;
  deviceId: string;
  deviceName: string;
  targetPower: boolean;
  targetValue: number;
}

/** 一次联动的完整触发记录 */
export interface TriggerRecord {
  id: string;
  /** 触发时间戳（毫秒） */
  time: number;
  /** 触发时的环境快照 */
  env: EnvState;
  /** 命中的规则名称，按执行顺序排列 */
  matchedRules: string[];
  steps: ExecutionStep[];
  changes: DeviceChange[];
  conflicts: ConflictItem[];
  /** 结果摘要 */
  note: string;
}

/** 规则引擎一次执行的返回值 */
export interface ExecutionResult {
  record: TriggerRecord;
  /** 执行后的设备状态（新数组，不修改入参） */
  devices: DeviceState[];
  /** 引擎是否真正改动了设备 */
  changed: boolean;
}

/** 环境场景预设 */
export interface ScenePreset {
  id: string;
  name: string;
  /** 场景说明 */
  desc: string;
  env: EnvState;
}

/** 环境数据项的元信息，供界面渲染与下拉选择使用 */
export interface EnvMeta {
  key: string;
  label: string;
  unit: string;
  min: number;
  max: number;
}

/** 4 项可调整环境数据的元信息 */
export const ENV_META_LIST: EnvMeta[] = [
  { key: ENV_TEMP, label: '温度', unit: '℃', min: 16, max: 35 },
  { key: ENV_HUMIDITY, label: '湿度', unit: '%', min: 20, max: 95 },
  { key: ENV_LIGHT, label: '光照', unit: '%', min: 0, max: 100 },
  { key: ENV_OCCUPANCY, label: '人员', unit: '', min: 0, max: 1 }
];

/** 所有可比较的运算符 */
export const OP_LIST: string[] = [OP_GT, OP_GTE, OP_LT, OP_LTE, OP_EQ];

/** 取环境项的中文名 */
export function envLabel(key: string): string {
  for (let i = 0; i < ENV_META_LIST.length; i++) {
    if (ENV_META_LIST[i].key === key) {
      return ENV_META_LIST[i].label;
    }
  }
  return key;
}

/** 取环境项的单位 */
export function envUnit(key: string): string {
  for (let i = 0; i < ENV_META_LIST.length; i++) {
    if (ENV_META_LIST[i].key === key) {
      return ENV_META_LIST[i].unit;
    }
  }
  return '';
}

/** 按环境键读取数值 */
export function readEnv(env: EnvState, key: string): number {
  if (key === ENV_TEMP) {
    return env.temp;
  }
  if (key === ENV_HUMIDITY) {
    return env.humidity;
  }
  if (key === ENV_LIGHT) {
    return env.light;
  }
  if (key === ENV_OCCUPANCY) {
    return env.occupancy;
  }
  return 0;
}

/** 深拷贝环境快照，避免界面直接持有引用 */
export function cloneEnv(env: EnvState): EnvState {
  const copy: EnvState = {
    temp: env.temp,
    humidity: env.humidity,
    light: env.light,
    occupancy: env.occupancy
  };
  return copy;
}

/** 深拷贝设备状态 */
export function cloneDevice(device: DeviceState): DeviceState {
  const copy: DeviceState = {
    id: device.id,
    name: device.name,
    type: device.type,
    power: device.power,
    value: device.value,
    unit: device.unit,
    min: device.min,
    max: device.max
  };
  return copy;
}

/** 深拷贝规则，编辑草稿时使用，避免污染原对象 */
export function cloneRule(rule: AutomationRule): AutomationRule {
  const conditions: RuleCondition[] = [];
  for (let i = 0; i < rule.conditions.length; i++) {
    const c = rule.conditions[i];
    const nc: RuleCondition = { key: c.key, op: c.op, value: c.value };
    conditions.push(nc);
  }
  const actions: RuleAction[] = [];
  for (let i = 0; i < rule.actions.length; i++) {
    const a = rule.actions[i];
    const na: RuleAction = { deviceId: a.deviceId, power: a.power, value: a.value };
    actions.push(na);
  }
  const copy: AutomationRule = {
    id: rule.id,
    name: rule.name,
    enabled: rule.enabled,
    priority: rule.priority,
    conditions: conditions,
    actions: actions
  };
  return copy;
}
