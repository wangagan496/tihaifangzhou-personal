export function resolveInterviewIcon(stem: string = '', subjectName: string = '', creatorName: string = ''): ResourceStr {
  const author = `${creatorName}|${subjectName}`.toLowerCase()
  if (author.includes('黑马') || author.includes('itheima')) {
    return $r('app.media.logo_heima')
  }

  const identity = `${stem}|${author}`.toLowerCase()
  if (identity.includes('顺丰科技') || identity.includes('顺丰快递') || identity.includes('顺丰速运') ||
    identity.includes('sf express')) {
    return $r('app.media.logo_sf')
  }
  if (identity.includes('去哪儿网') || identity.includes('去哪儿') || identity.includes('qunar')) {
    return $r('app.media.logo_qunar')
  }
  if (identity.includes('猿辅导') || identity.includes('yuanfudao')) {
    return $r('app.media.logo_yuanfudao')
  }
  if (identity.includes('中电金信') || identity.includes('gientech')) {
    return $r('app.media.logo_gientech')
  }
  if (identity.includes('用友') || identity.includes('yonyou')) {
    return $r('app.media.logo_yonyou')
  }
  if (identity.includes('海南易睿') || identity.includes('易睿网络')) {
    return $r('app.media.logo_hainan_yirui')
  }
  if (identity.includes('搜狐') || identity.includes('sohu')) {
    return $r('app.media.logo_sohu')
  }
  if (identity.includes('龙席网络') || identity.includes('loonxi')) {
    return $r('app.media.logo_loonxi')
  }
  if (identity.includes('迪卡侬') || identity.includes('decathlon')) {
    return $r('app.media.logo_decathlon')
  }
  if (identity.includes('好未来') || identity.includes('tal education')) {
    return $r('app.media.logo_tal')
  }
  if (identity.includes('明席卡乐') || identity.includes('mcolor')) {
    return $r('app.media.logo_mcolor')
  }
  if (identity.includes('敏智信息')) {
    return $r('app.media.logo_minzhi')
  }
  if (identity.includes('凤凰科技') || identity.includes('凤凰网') || identity.includes('ifeng')) {
    return $r('app.media.logo_ifeng')
  }
  if (identity.includes('软通动力') || identity.includes('isoftstone')) {
    return $r('app.media.logo_isoftstone')
  }
  if (identity.includes('知音科技') || identity.includes('路知音') || identity.includes('cartizan')) {
    return $r('app.media.logo_zhiyin')
  }
  if (identity.includes('深圳亿达') || identity.includes('亿达信息') || identity.includes('yidatec')) {
    return $r('app.media.logo_yidatec')
  }
  if (identity.includes('平云信息') || identity.includes('平云科技') || identity.includes('pingyun')) {
    return $r('app.media.logo_pingyun')
  }
  if (identity.includes('宇信科技') || identity.includes('yusys')) {
    return $r('app.media.logo_yusys')
  }
  if (identity.includes('花旗银行') || identity.includes('citibank') || identity.includes('citi bank')) {
    return $r('app.media.logo_citibank')
  }
  if (identity.includes('云纵互联网') || identity.includes('广州云纵') || identity.includes('yun zong')) {
    return $r('app.media.logo_yunzong')
  }
  if (identity.includes('趣步科技') || identity.includes('tripodeck')) {
    return $r('app.media.logo_tripodeck')
  }
  if (identity.includes('浙江大华') || identity.includes('大华科技') || identity.includes('dahuatech')) {
    return $r('app.media.logo_dahua')
  }
  if (identity.includes('网易有道') || identity.includes('有道') || identity.includes('youdao')) {
    return $r('app.media.logo_youdao')
  }
  if (identity.includes('京东金融') || identity.includes('jd finance')) {
    return $r('app.media.logo_jd_finance')
  }
  if (identity.includes('一声笑科技') || identity.includes('1mii')) {
    return $r('app.media.logo_1mii')
  }
  if (identity.includes('滴滴') || identity.includes('didi')) {
    return $r('app.media.logo_didi')
  }
  if (identity.includes('微软') || identity.includes('microsoft')) {
    return $r('app.media.logo_microsoft')
  }
  if (identity.includes('链家') || identity.includes('lianjia')) {
    return $r('app.media.logo_lianjia')
  }
  if (identity.includes('字节跳动') || identity.includes('宇宙头条') || identity.includes('今日头条') ||
    identity.includes('抖音') || identity.includes('bytedance')) {
    return $r('app.media.logo_bytedance')
  }
  if (identity.includes('知乎') || identity.includes('zhihu')) {
    return $r('app.media.logo_zhihu')
  }
  if (identity.includes('蔚来') || identity.includes('nio')) {
    return $r('app.media.logo_nio')
  }
  if (identity.includes('新浪') || identity.includes('微博') || identity.includes('sina')) {
    return $r('app.media.logo_sina')
  }
  if (identity.includes('百度') || identity.includes('baidu')) {
    return $r('app.media.logo_baidu')
  }
  if (identity.includes('阿里') || identity.includes('淘宝') || identity.includes('天猫') ||
    identity.includes('蚂蚁') || identity.includes('alibaba')) {
    return $r('app.media.logo_alibaba')
  }
  if (identity.includes('腾讯') || identity.includes('微信') || identity.includes('qq')) {
    return $r('app.media.logo_tencent')
  }
  if (identity.includes('华为') || identity.includes('huawei')) {
    return $r('app.media.logo_huawei')
  }
  if (identity.includes('美团') || identity.includes('meituan')) {
    return $r('app.media.logo_meituan')
  }
  if (identity.includes('小米') || identity.includes('xiaomi')) {
    return $r('app.media.logo_xiaomi')
  }
  if (identity.includes('快手') || identity.includes('kuaishou')) {
    return $r('app.media.logo_kuaishou')
  }
  if (identity.includes('哔哩哔哩') || identity.includes('bilibili') || identity.includes('b站')) {
    return $r('app.media.logo_bilibili')
  }
  if (identity.includes('小红书') || identity.includes('xiaohongshu')) {
    return $r('app.media.logo_xiaohongshu')
  }
  return $r('app.media.ic_interview_card')
}
