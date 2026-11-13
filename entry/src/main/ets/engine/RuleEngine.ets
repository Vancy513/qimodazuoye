/**
 * 联动实验室 —— 规则引擎
 *
 * 纯函数实现：输入规则集、设备集、环境快照，输出执行结果与新的设备状态。
 * 不依赖 @ohos 能力，因此可以在本地单元测试中直接验证。
 */
import {
  AutomationRule, DeviceState, EnvState, ExecutionResult, ExecutionStep,
  DeviceChange, ConflictItem, TriggerRecord, RuleCondition, RuleAction,
  OP_GT, OP_GTE, OP_LT, OP_LTE, OP_EQ, ENV_OCCUPANCY, envLabel, readEnv, cloneEnv, cloneDevice
} from '../model/LabTypes';

/** 数值比较，统一处理 5 种运算符 */
export function compare(actual: number, op: string, target: number): boolean {
  if (op === OP_GT) {
    return actual > target;
  }
  if (op === OP_GTE) {
    return actual >= target;
  }
  if (op === OP_LT) {
    return actual < target;
  }
  if (op === OP_LTE) {
    return actual <= target;
  }
  if (op === OP_EQ) {
    return Math.abs(actual - target) < 0.000001;
  }
  return false;
}

/** 判断单个条件是否成立 */
export function evaluateCondition(condition: RuleCondition, env: EnvState): boolean {
  if (condition === null || condition === undefined) {
    return false;
  }
  const actual: number = readEnv(env, condition.key);
  return compare(actual, condition.op, condition.value);
}

/**
 * 判断整条规则是否命中：所有条件取「与」，且条件列表不能为空。
 * 空条件规则视为无效规则，永不命中，避免「无条件触发」造成的误动作。
 */
export function evaluateRule(rule: AutomationRule, env: EnvState): boolean {
  if (rule === null || rule === undefined || !rule.enabled) {
    return false;
  }
  if (rule.conditions.length === 0) {
    return false;
  }
  for (let i = 0; i < rule.conditions.length; i++) {
    if (!evaluateCondition(rule.conditions[i], env)) {
      return false;
    }
  }
  return true;
}

/**
 * 规则排序：优先级降序；优先级相同时保持原始列表顺序（稳定排序）。
 * 返回新数组，不修改入参。
 */
export function sortRulesByPriority(rules: AutomationRule[]): AutomationRule[] {
  const indexed: AutomationRule[] = [];
  for (let i = 0; i < rules.length; i++) {
    indexed.push(rules[i]);
  }
  // 插入排序，天然稳定，规模很小无需担心性能
  for (let i = 1; i < indexed.length; i++) {
    const current: AutomationRule = indexed[i];
    let j: number = i - 1;
    while (j >= 0 && indexed[j].priority < current.priority) {
      indexed[j + 1] = indexed[j];
      j--;
    }
    indexed[j + 1] = current;
  }
  return indexed;
}

/** 按设备 id 查找设备，找不到返回 null */
export function findDevice(devices: DeviceState[], deviceId: string): DeviceState | null {
  for (let i = 0; i < devices.length; i++) {
    if (devices[i].id === deviceId) {
      return devices[i];
    }
  }
  return null;
}

/** 把数值限制在 [min, max] 区间内 */
export function clamp(value: number, min: number, max: number): number {
  if (value < min) {
    return min;
  }
  if (value > max) {
    return max;
  }
  return value;
}

/**
 * 执行一次联动。
 *
 * 执行规则：
 * 1. 仅启用且命中的规则参与执行；
 * 2. 按优先级从高到低执行，同优先级按规则列表顺序；
 * 3. 同一台设备在一轮联动中只接受一次控制，先执行者胜出，
 *    被压制的一方写入 conflicts，保证「冲突有明确处理顺序」。
 */
export function runRules(rules: AutomationRule[], devices: DeviceState[], env: EnvState,
  now: number, recordId: string): ExecutionResult {
  const sorted: AutomationRule[] = sortRulesByPriority(rules);
  // 工作副本，保证不修改入参
  const working: DeviceState[] = [];
  for (let i = 0; i < devices.length; i++) {
    working.push(cloneDevice(devices[i]));
  }

  const matchedRules: string[] = [];
  const steps: ExecutionStep[] = [];
  const changes: DeviceChange[] = [];
  const conflicts: ConflictItem[] = [];
  const claimedDeviceIds: string[] = [];
  const claimedRuleNames: string[] = [];
  let order: number = 1;

  for (let i = 0; i < sorted.length; i++) {
    const rule: AutomationRule = sorted[i];
    if (!evaluateRule(rule, env)) {
      continue;
    }
    matchedRules.push(rule.name);
    for (let j = 0; j < rule.actions.length; j++) {
      const action: RuleAction = rule.actions[j];
      const target: DeviceState | null = findDevice(working, action.deviceId);
      if (target === null) {
        // 引用了不存在的设备：忽略该动作，不中断整轮执行
        continue;
      }
      const claimedIndex: number = claimedDeviceIds.indexOf(action.deviceId);
      if (claimedIndex >= 0) {
        const sameTarget: boolean = target.power === action.power;
        if (!sameTarget) {
          const conflict: ConflictItem = {
            deviceId: action.deviceId,
            deviceName: target.name,
            winnerRuleId: '',
            winnerRuleName: claimedRuleNames[claimedIndex],
            skippedRuleId: rule.id,
            skippedRuleName: rule.name
          };
          conflicts.push(conflict);
        }
        continue;
      }
      const beforePower: boolean = target.power;
      const beforeValue: number = target.value;
      // 开启类动作把数值收敛到设备可调区间；关闭类动作保留原设定值，避免出现「关闭 16℃」这类无意义数值
      const afterValue: number = action.power ? clamp(action.value, target.min, target.max) : target.value;
      target.power = action.power;
      target.value = afterValue;
      claimedDeviceIds.push(action.deviceId);
      claimedRuleNames.push(rule.name);
      steps.push({
        order: order,
        ruleId: rule.id,
        ruleName: rule.name,
        deviceId: target.id,
        deviceName: target.name,
        targetPower: action.power,
        targetValue: afterValue
      });
      order++;
      if (beforePower !== target.power || Math.abs(beforeValue - afterValue) > 0.000001) {
        changes.push({
          deviceId: target.id,
          deviceName: target.name,
          beforePower: beforePower,
          afterPower: target.power,
          beforeValue: beforeValue,
          afterValue: afterValue
        });
      }
    }
  }

  let note: string = '';
  if (matchedRules.length === 0) {
    note = '没有规则命中，设备保持原状';
  } else if (conflicts.length > 0) {
    note = '命中 ' + matchedRules.length + ' 条规则，发生 ' + conflicts.length + ' 处冲突，已按优先级处理';
  } else {
    note = '命中 ' + matchedRules.length + ' 条规则，执行 ' + steps.length + ' 个设备动作';
  }

  const record: TriggerRecord = {
    id: recordId,
    time: now,
    env: cloneEnv(env),
    matchedRules: matchedRules,
    steps: steps,
    changes: changes,
    conflicts: conflicts,
    note: note
  };

  return {
    record: record,
    devices: working,
    changed: changes.length > 0
  };
}

/**
 * 规则合法性校验，返回错误信息数组；空数组代表校验通过。
 * 用于保存前拦截非法数据（空条件、引用不存在设备、数值越界等）。
 */
export function validateRule(rule: AutomationRule, devices: DeviceState[]): string[] {
  const errors: string[] = [];
  if (rule.name === null || rule.name === undefined || rule.name.trim().length === 0) {
    errors.push('规则名称不能为空');
  }
  if (rule.conditions.length === 0) {
    errors.push('至少需要一个触发条件');
  }
  if (rule.conditions.length > 2) {
    errors.push('最多支持两个触发条件');
  }
  for (let i = 0; i < rule.conditions.length; i++) {
    const c: RuleCondition = rule.conditions[i];
    if (c.key !== 'temp' && c.key !== 'humidity' && c.key !== 'light' && c.key !== ENV_OCCUPANCY) {
      errors.push('第 ' + (i + 1) + ' 个条件的环境项无效');
    }
  }
  if (rule.actions.length === 0) {
    errors.push('至少需要一个设备动作');
  }
  for (let i = 0; i < rule.actions.length; i++) {
    const a: RuleAction = rule.actions[i];
    const device: DeviceState | null = findDevice(devices, a.deviceId);
    if (device === null) {
      errors.push('第 ' + (i + 1) + ' 个动作引用了不存在的设备');
    } else if (a.value < device.min || a.value > device.max) {
      errors.push(device.name + ' 的目标值超出 ' + device.min + '~' + device.max + ' 范围');
    }
  }
  if (rule.priority < 1 || rule.priority > 5) {
    errors.push('优先级取值范围为 1~5');
  }
  return errors;
}

/** 统计当前环境下会命中的规则数量，用于界面实时提示 */
export function countMatchedRules(rules: AutomationRule[], env: EnvState): number {
  let count: number = 0;
  for (let i = 0; i < rules.length; i++) {
    if (evaluateRule(rules[i], env)) {
      count++;
    }
  }
  return count;
}

/** 把条件格式化为可读文本，例如「温度 > 28」 */
export function formatCondition(condition: RuleCondition): string {
  const unit: string = condition.key === ENV_OCCUPANCY ? '' :
    (condition.key === 'temp' ? '℃' : (condition.key === 'humidity' ? '%' : '%'));
  if (condition.key === ENV_OCCUPANCY) {
    const state: string = condition.value >= 1 ? '有人' : '无人';
    return '人员 = ' + state;
  }
  return envLabel(condition.key) + ' ' + condition.op + ' ' + condition.value + unit;
}

/** 把规则格式化为「条件 → 动作」的一句话描述 */
export function formatRuleSummary(rule: AutomationRule, devices: DeviceState[]): string {
  let text: string = '';
  for (let i = 0; i < rule.conditions.length; i++) {
    if (i > 0) {
      text += ' 且 ';
    }
    text += formatCondition(rule.conditions[i]);
  }
  text += ' → ';
  for (let i = 0; i < rule.actions.length; i++) {
    if (i > 0) {
      text += '，';
    }
    const a: RuleAction = rule.actions[i];
    const device: DeviceState | null = findDevice(devices, a.deviceId);
    const deviceName: string = device === null ? '未知设备' : device.name;
    text += (a.power ? '开启 ' : '关闭 ') + deviceName;
  }
  return text;
}

/** 时间戳格式化为 HH:mm:ss */
export function formatTime(timestamp: number): string {
  const date: Date = new Date(timestamp);
  const hh: string = date.getHours() < 10 ? '0' + date.getHours() : '' + date.getHours();
  const mm: string = date.getMinutes() < 10 ? '0' + date.getMinutes() : '' + date.getMinutes();
  const ss: string = date.getSeconds() < 10 ? '0' + date.getSeconds() : '' + date.getSeconds();
  return hh + ':' + mm + ':' + ss;
}
