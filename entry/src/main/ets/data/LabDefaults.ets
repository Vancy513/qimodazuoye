/**
 * 联动实验室 —— 初始数据（Mock 数据层）
 *
 * 首次启动或本地存储为空时使用，保证应用冷启动即可演示完整业务闭环。
 */
import {
  DeviceState, EnvState, AutomationRule, ScenePreset,
  DEV_LIGHT, DEV_AC, DEV_CURTAIN, DEV_HUMIDIFIER,
  ENV_TEMP, ENV_HUMIDITY, ENV_LIGHT, ENV_OCCUPANCY,
  OP_GT, OP_LT, OP_EQ, OP_GTE
} from '../model/LabTypes';

/** 4 类可控设备 */
export function createDefaultDevices(): DeviceState[] {
  const devices: DeviceState[] = [
    {
      id: 'dev_light', name: '吸顶灯', type: DEV_LIGHT,
      power: false, value: 0, unit: '%', min: 0, max: 100
    },
    {
      id: 'dev_ac', name: '空调', type: DEV_AC,
      power: false, value: 26, unit: '℃', min: 16, max: 30
    },
    {
      id: 'dev_curtain', name: '窗帘', type: DEV_CURTAIN,
      power: false, value: 0, unit: '%', min: 0, max: 100
    },
    {
      id: 'dev_humidifier', name: '加湿器', type: DEV_HUMIDIFIER,
      power: false, value: 0, unit: '%', min: 0, max: 100
    }
  ];
  return devices;
}

/** 默认环境：夏日午后，宿舍有人 */
export function createDefaultEnv(): EnvState {
  const env: EnvState = {
    temp: 29,
    humidity: 38,
    light: 25,
    occupancy: 1
  };
  return env;
}

/** 6 条预置规则：含 1 条双条件规则，且预置了一组可复现的优先级冲突 */
export function createDefaultRules(): AutomationRule[] {
  const rules: AutomationRule[] = [
    {
      id: 'rule_ac_hot', name: '高温开空调', enabled: true, priority: 3,
      conditions: [{ key: ENV_TEMP, op: OP_GT, value: 28 }],
      actions: [{ deviceId: 'dev_ac', power: true, value: 24 }]
    },
    {
      id: 'rule_light_dark', name: '昏暗开灯', enabled: true, priority: 4,
      conditions: [
        { key: ENV_LIGHT, op: OP_LT, value: 30 },
        { key: ENV_OCCUPANCY, op: OP_EQ, value: 1 }
      ],
      actions: [{ deviceId: 'dev_light', power: true, value: 70 }]
    },
    {
      id: 'rule_light_off', name: '无人熄灯', enabled: true, priority: 5,
      conditions: [{ key: ENV_OCCUPANCY, op: OP_EQ, value: 0 }],
      actions: [{ deviceId: 'dev_light', power: false, value: 0 }]
    },
    {
      id: 'rule_ac_eco', name: '无人省电关空调', enabled: true, priority: 5,
      conditions: [{ key: ENV_OCCUPANCY, op: OP_EQ, value: 0 }],
      actions: [{ deviceId: 'dev_ac', power: false, value: 0 }]
    },
    {
      id: 'rule_humidify', name: '干燥加湿', enabled: true, priority: 2,
      conditions: [{ key: ENV_HUMIDITY, op: OP_LT, value: 40 }],
      actions: [{ deviceId: 'dev_humidifier', power: true, value: 60 }]
    },
    {
      id: 'rule_curtain', name: '潮湿关窗', enabled: true, priority: 3,
      conditions: [{ key: ENV_HUMIDITY, op: OP_GT, value: 80 }],
      actions: [{ deviceId: 'dev_curtain', power: false, value: 0 }]
    }
  ];
  return rules;
}

/** 5 组环境演练场景（满足「至少 2 组」要求） */
export function createDefaultScenes(): ScenePreset[] {
  const scenes: ScenePreset[] = [
    {
      id: 'scene_study', name: '白天自习', desc: '光照充足、有人在宿舍，适合验证「不应开灯」的负向用例',
      env: { temp: 26, humidity: 52, light: 82, occupancy: 1 }
    },
    {
      id: 'scene_night', name: '深夜休息', desc: '昏暗且无人，「昏暗开灯」因要求有人而不命中，验证条件互斥时不会误报冲突',
      env: { temp: 24, humidity: 60, light: 8, occupancy: 0 }
    },
    {
      id: 'scene_wet', name: '回南天', desc: '湿度超过 80%，验证「潮湿关窗」单独生效',
      env: { temp: 22, humidity: 88, light: 45, occupancy: 1 }
    },
    {
      id: 'scene_summer', name: '夏日午后', desc: '高温、低湿、昏暗且有人，多条规则同时命中',
      env: { temp: 31, humidity: 36, light: 22, occupancy: 1 }
    },
    {
      id: 'scene_empty', name: '空宿舍午后', desc: '30℃ 但房间无人：「无人省电关空调」与「高温开空调」冲突，前者优先级更高',
      env: { temp: 30, humidity: 55, light: 60, occupancy: 0 }
    }
  ];
  return scenes;
}
