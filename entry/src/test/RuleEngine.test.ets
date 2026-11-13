/**
 * 联动实验室 —— 规则引擎单元测试
 *
 * 覆盖正常、边界、异常三类场景，共 10 条用例。
 * 运行方式：在 DevEco Studio 中右键 entry/src/test 目录，
 * 选择 Run 'Tests in entry'（本地单元测试，无需连接设备）。
 */
import { describe, beforeAll, it, expect } from '@ohos/hypium';
import {
  AutomationRule, DeviceState, EnvState, ExecutionResult,
  ENV_TEMP, ENV_HUMIDITY, ENV_LIGHT, ENV_OCCUPANCY, OP_GT, OP_GTE, OP_LT, OP_EQ
} from '../main/ets/model/LabTypes';
import { runRules, validateRule, evaluateRule, findDevice } from '../main/ets/engine/RuleEngine';

/** 构造 4 台可控设备的测试夹具 */
function createDevices(): DeviceState[] {
  const devices: DeviceState[] = [
    { id: 'dev_light', name: '吸顶灯', type: 'light', power: false, value: 0, unit: '%', min: 0, max: 100 },
    { id: 'dev_ac', name: '空调', type: 'ac', power: false, value: 26, unit: '℃', min: 16, max: 30 },
    { id: 'dev_curtain', name: '窗帘', type: 'curtain', power: false, value: 0, unit: '%', min: 0, max: 100 },
    { id: 'dev_humidifier', name: '加湿器', type: 'humidifier', power: false, value: 0, unit: '%', min: 0, max: 100 }
  ];
  return devices;
}

/** 构造单条件规则 */
function acRule(id: string, name: string, priority: number, threshold: number): AutomationRule {
  const rule: AutomationRule = {
    id: id,
    name: name,
    enabled: true,
    priority: priority,
    conditions: [{ key: ENV_TEMP, op: OP_GT, value: threshold }],
    actions: [{ deviceId: 'dev_ac', power: true, value: 24 }]
  };
  return rule;
}

export default function ruleEngineTest() {
  describe('RuleEngineTest', () => {
    beforeAll(() => {
      // 无全局初始化，测试用例各自构造独立数据，保证互不影响
    });

    // 正常场景：单条件规则命中，设备状态被改变
    it('normal_single_condition_triggers_device', 0, () => {
      const devices: DeviceState[] = createDevices();
      const rules: AutomationRule[] = [acRule('r1', '高温开空调', 3, 28)];
      const env: EnvState = { temp: 30, humidity: 50, light: 60, occupancy: 1 };
      const result: ExecutionResult = runRules(rules, devices, env, 1000, 'log_1');
      expect(result.record.matchedRules.length).assertEqual(1);
      expect(result.record.steps.length).assertEqual(1);
      expect(result.devices[1].power).assertTrue();
      expect(result.devices[1].value).assertEqual(24);
      expect(result.changed).assertTrue();
    });

    // 正常场景：双条件规则必须在两个条件同时满足时才命中
    it('normal_two_conditions_require_both', 0, () => {
      const devices: DeviceState[] = createDevices();
      const dualRule: AutomationRule = {
        id: 'r_dual', name: '昏暗且有人开灯', enabled: true, priority: 4,
        conditions: [
          { key: ENV_LIGHT, op: OP_LT, value: 30 },
          { key: ENV_OCCUPANCY, op: OP_EQ, value: 1 }
        ],
        actions: [{ deviceId: 'dev_light', power: true, value: 70 }]
      };
      const rules: AutomationRule[] = [dualRule];
      const bothMet: EnvState = { temp: 25, humidity: 50, light: 20, occupancy: 1 };
      const onlyLightMet: EnvState = { temp: 25, humidity: 50, light: 20, occupancy: 0 };
      expect(evaluateRule(dualRule, bothMet)).assertTrue();
      expect(evaluateRule(dualRule, onlyLightMet)).assertFalse();
      const result: ExecutionResult = runRules(rules, devices, bothMet, 1001, 'log_2');
      expect(result.record.matchedRules.length).assertEqual(1);
      expect(result.devices[0].power).assertTrue();
    });

    // 边界场景：严格大于运算符在阈值相等时不触发
    it('boundary_greater_than_equal_threshold_not_trigger', 0, () => {
      const devices: DeviceState[] = createDevices();
      const rules: AutomationRule[] = [acRule('r1', '高温开空调', 3, 28)];
      const env: EnvState = { temp: 28, humidity: 50, light: 60, occupancy: 1 };
      const result: ExecutionResult = runRules(rules, devices, env, 1002, 'log_3');
      expect(result.record.matchedRules.length).assertEqual(0);
      expect(result.devices[1].power).assertFalse();
      expect(result.changed).assertFalse();
    });

    // 边界场景：大于等于运算符在阈值相等时应触发
    it('boundary_greater_equal_threshold_trigger', 0, () => {
      const devices: DeviceState[] = createDevices();
      const rule: AutomationRule = {
        id: 'r_gte', name: '温度达到 28 开空调', enabled: true, priority: 3,
        conditions: [{ key: ENV_TEMP, op: OP_GTE, value: 28 }],
        actions: [{ deviceId: 'dev_ac', power: true, value: 24 }]
      };
      const env: EnvState = { temp: 28, humidity: 50, light: 60, occupancy: 1 };
      const result: ExecutionResult = runRules([rule], devices, env, 1003, 'log_4');
      expect(result.record.matchedRules.length).assertEqual(1);
      expect(result.devices[1].power).assertTrue();
    });

    // 边界场景：设备目标值超出上下界时被收敛到边界值
    it('boundary_action_value_clamped', 0, () => {
      const devices: DeviceState[] = createDevices();
      const rule: AutomationRule = {
        id: 'r_clamp', name: '空调强力制冷', enabled: true, priority: 3,
        conditions: [{ key: ENV_TEMP, op: OP_GT, value: 30 }],
        actions: [{ deviceId: 'dev_ac', power: true, value: 10 }]
      };
      const env: EnvState = { temp: 33, humidity: 50, light: 60, occupancy: 1 };
      const result: ExecutionResult = runRules([rule], devices, env, 1004, 'log_5');
      expect(result.devices[1].value).assertEqual(16);
    });

    // 异常场景：两条规则控制同一设备，高优先级生效且冲突被记录
    it('exception_conflict_resolved_by_priority', 0, () => {
      const devices: DeviceState[] = createDevices();
      const lightOn: AutomationRule = {
        id: 'r_on', name: '昏暗开灯', enabled: true, priority: 4,
        conditions: [{ key: ENV_LIGHT, op: OP_LT, value: 30 }],
        actions: [{ deviceId: 'dev_light', power: true, value: 70 }]
      };
      const lightOff: AutomationRule = {
        id: 'r_off', name: '无人熄灯', enabled: true, priority: 5,
        conditions: [{ key: ENV_OCCUPANCY, op: OP_EQ, value: 0 }],
        actions: [{ deviceId: 'dev_light', power: false, value: 0 }]
      };
      const env: EnvState = { temp: 25, humidity: 50, light: 10, occupancy: 0 };
      const result: ExecutionResult = runRules([lightOn, lightOff], devices, env, 1005, 'log_6');
      expect(result.record.conflicts.length).assertEqual(1);
      expect(result.record.conflicts[0].skippedRuleName).assertEqual('昏暗开灯');
      expect(result.record.conflicts[0].winnerRuleName).assertEqual('无人熄灯');
      // 熄灯规则优先级更高，最终灯应处于关闭状态
      expect(result.devices[0].power).assertFalse();
      // 执行顺序中只能出现一次对该设备的控制
      expect(result.record.steps.length).assertEqual(1);
    });

    // 异常场景：停用的规则即使条件满足也不执行
    it('exception_disabled_rule_not_executed', 0, () => {
      const devices: DeviceState[] = createDevices();
      const disabled: AutomationRule = acRule('r_disabled', '已停用的空调规则', 3, 28);
      disabled.enabled = false;
      const env: EnvState = { temp: 32, humidity: 50, light: 60, occupancy: 1 };
      const result: ExecutionResult = runRules([disabled], devices, env, 1006, 'log_7');
      expect(result.record.matchedRules.length).assertEqual(0);
      expect(result.devices[1].power).assertFalse();
    });

    // 异常场景：规则引用了不存在的设备时安全跳过，不抛异常
    it('exception_invalid_device_ignored', 0, () => {
      const devices: DeviceState[] = createDevices();
      const badRule: AutomationRule = {
        id: 'r_bad', name: '错误设备规则', enabled: true, priority: 3,
        conditions: [{ key: ENV_TEMP, op: OP_GT, value: 20 }],
        actions: [{ deviceId: 'dev_not_exist', power: true, value: 50 }]
      };
      const env: EnvState = { temp: 25, humidity: 50, light: 60, occupancy: 1 };
      const result: ExecutionResult = runRules([badRule], devices, env, 1007, 'log_8');
      expect(result.record.matchedRules.length).assertEqual(1);
      expect(result.record.steps.length).assertEqual(0);
      expect(result.record.changes.length).assertEqual(0);
      const missing: DeviceState | null = findDevice(result.devices, 'dev_not_exist');
      expect(missing === null).assertTrue();
    });

    // 异常场景：非法规则在保存前被校验拦截
    it('exception_validate_rule_rejects_invalid_input', 0, () => {
      const devices: DeviceState[] = createDevices();
      const emptyRule: AutomationRule = {
        id: 'r_empty', name: '  ', enabled: true, priority: 9,
        conditions: [],
        actions: [{ deviceId: 'dev_not_exist', power: true, value: 999 }]
      };
      const errors: string[] = validateRule(emptyRule, devices);
      expect(errors.length).assertEqual(4);
      expect(errors[0]).assertEqual('规则名称不能为空');
    });

    // 数据恢复场景：JSON 序列化再反序列化后规则可完整还原（模拟进程重启）
    it('normal_rule_json_round_trip', 0, () => {
      const original: AutomationRule[] = [acRule('r1', '高温开空调', 3, 28)];
      const text: string = JSON.stringify(original);
      const restored: AutomationRule[] = JSON.parse(text) as AutomationRule[];
      expect(restored.length).assertEqual(1);
      expect(restored[0].id).assertEqual('r1');
      expect(restored[0].conditions[0].key).assertEqual(ENV_TEMP);
      expect(restored[0].conditions[0].value).assertEqual(28);
      expect(restored[0].actions[0].deviceId).assertEqual('dev_ac');
      // 恢复后仍可正常参与计算
      const devices: DeviceState[] = createDevices();
      const env: EnvState = { temp: 29, humidity: 50, light: 60, occupancy: 1 };
      const result: ExecutionResult = runRules(restored, devices, env, 1008, 'log_9');
      expect(result.record.matchedRules.length).assertEqual(1);
    });
  });
}
