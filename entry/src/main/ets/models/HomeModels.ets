import { QuestionItem } from '../views/home/QuestionItemComp';

export interface IClockRes {
  /**
   * 请求成功10000标志
   */
  code: number;

  /**
   * 返回数据
   */
  data: IClockData;

  /**
   * 请求成功
   */
  message: string;

  /**
   * 请求成功标志
   */
  success: boolean;
}

/**
 * 返回数据
 */
export interface IClockData {
  /**
   * 连续签到天数
   */
  clockinNumbers: number;

  /**
   * 签到信息
   */
  clockins: Clockin[];

  /**
   * 当天是否签到
   */
  flag: boolean;

  /**
   * 累计签到天数
   */
  totalClockinNumber: number;
}

export interface Clockin {
  /**
   * 签到时间
   */
  createdAt: string;
  id: string;
}


export interface IListData {
  /**
   * 总页数
   */
  pageTotal: number;

  /**
   * 数据集合
   */
  rows: QuestionItem[];

  /**
   * 总数
   */
  total: number;
}


// 埋点相关
export interface TimeItem {
  questionId: string;
  startTime: number;
  endTime: number;
}

export interface TrackData {
  timeList: TimeItem[];
}
