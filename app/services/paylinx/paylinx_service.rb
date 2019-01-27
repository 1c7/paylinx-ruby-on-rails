# 说明: 此处是 Paylinx 支付的核心代码
# Paylinx 官网: http://www.paylinx.com.au/
# Paylinx 文档: http://paylinx.cn/doc/index.html#api-Wechat-PostWxpayGatewayUnifiedorder
module Paylinx
  class PaylinxService
    def create_qr_code_payment(out_trade_no, # 商户订单号，须确保商户系统内唯一
                               total_fee_in_AUD_in_cent, # 订单金额, 货币: AUD, 单位: 分
                               body, # 交易说明
                               notify_url # 支付通知URL
                              )
      # ---- Config ----
        # 请求 URL
        base_URL = "https://paylinx.cn/wxpay/gateway/unifiedorder/"
        # Paylinx 颁发的 key(仅示例用途，数据已脱敏混淆)
        key = "i111HhkA0cHoYC29d9Z222OTYMAIzzz2T"
        # 商户号(仅示例用途，数据已脱敏混淆)
        mch_id = 11112222
      # ---- Config ----

      # 获得当前 ip
      ip = Socket.ip_address_list.detect{|intf| intf.ipv4_private?}
      spbill_create_ip = ip.ip_address if ip

      # 随机字符串
      nonce_str = SecureRandom.uuid.tr('-', '')

      # 构建参数, 待会用这个 hash 签名
      @hash = {
        mch_id: mch_id, # 商户号
        nonce_str: nonce_str, # 随机字符串
        notify_url: notify_url, # 支付通知URL
        out_trade_no: out_trade_no, # 商户订单号，须确保商户系统内唯一
        body: body, # 交易说明
        spbill_create_ip: spbill_create_ip, # 交易创建方的IP
        total_fee: total_fee_in_AUD_in_cent, # 交易金额，单位：分
        fee_type: 'AUD', # 交易金额对应的货币币种，如：AUD
        trade_type: "NATIVE",
      }
      # 签名
      sign = sign_paylinx(@hash, key)
      # 构建 xml
      payload = Nokogiri::XML::Builder.new do |xml|
        xml.xml {
          xml.mch_id @hash[:mch_id]
          xml.store_id @hash[:store_id]
          xml.nonce_str @hash[:nonce_str]
          xml.notify_url @hash[:notify_url]
          xml.out_trade_no @hash[:out_trade_no]
          xml.body @hash[:body]
          xml.spbill_create_ip @hash[:spbill_create_ip]
          xml.total_fee @hash[:total_fee]
          xml.fee_type @hash[:fee_type]
          xml.trade_type @hash[:trade_type]
          xml.sign sign
        }
      end
      # 发送请求
      payload_in_xml = payload.to_xml
      http_return = RestClient.post(base_URL, payload_in_xml, :accept => :xml, :content_type => :xml)
      result = http_return.body
      # 原样返回结果，不做任何修改
      return result
=begin
      返回格式:
      <?xml version="1.0"?>
      <xml>
        <mch_id><![CDATA[x]]></mch_id>
        <store_id><![CDATA[536]]></store_id>
        <nonce_str><![CDATA[cgdm53fsrjhxuc04po2vvmnvbmj74m7s]]></nonce_str>
        <notify_url><![CDATA[https://x.herokuapp.com/pay_response]]></notify_url>
        <out_trade_no><![CDATA[2019012900001111]]></out_trade_no>
        <body><![CDATA[test body]]></body>
        <spbill_create_ip><![CDATA[192.168.5.25]]></spbill_create_ip>
        <total_fee><![CDATA[200]]></total_fee>
        <fee_type><![CDATA[AUD]]></fee_type>
        <trade_type><![CDATA[NATIVE]]></trade_type>
        <sign><![CDATA[2226B69DE163a29F3953k02D60C7zzzz]]></sign>
        <prepay_id><![CDATA[wx12174652278867565b2e86f23020834255]]></prepay_id>
        <code_url><![CDATA[weixin://wxpay/bizpayurl?pr=eksyR83]]></code_url>
        <paylinx_order_no><![CDATA[20190127198767868998176826]]></paylinx_order_no>
        <return_code><![CDATA[SUCCESS]]></return_code>
        <return_msg><![CDATA[OK]]></return_msg>
        <result_code><![CDATA[SUCCESS]]></result_code>
      </xml>
=begin
      在如上的 xml 返回结果中, 除了原样返回我们发过去的参数, 多了6个东西:
        1. prepay_id
        2. code_url
        3. paylinx_order_no
        4. return_code
        5. return_msg
        6. result_code

      其中:
        4. return_code
        5. return_msg
        6. result_code
        只是为了表示状态

      有价值的是:
        1. prepay_id
        2. code_url
        3. paylinx_order_no
=end
    end

    # 签名
    def sign_paylinx(params, key)
      query = params.sort.map do |k, v|
        "#{k}=#{v}" if v.to_s != ''
      end.compact.join('&')
      query = query + '&key=' + key
      md5 = Digest::MD5.hexdigest(query)
      upcase = md5.upcase
      result = upcase
      return result
    end

    # 验证支付回调的签名
    # content 输入举例:
=begin
{"xml"=>
  {"bank_type"=>"CFT",
    "cash_fee"=>"647",
    "cash_fee_type"=>"CNY",
    "fee_type"=>"AUD",
    "result_code"=>"SUCCESS",
    "return_code"=>"SUCCESS",
    "time_end"=>"20190127215907",
    "total_fee"=>"133",
    "transaction_id"=>"4200000281201901278642575461",
    "mch_id"=>"11112222",
    "nonce_str"=>"8ds5urusar3pezenosp6izwfu8nhcdq3",
    "out_trade_no"=>"Paylinx1548597530084",
    "platform"=>"wechat",
    "sign"=>"8FF02E09AD592B22842A227D945224B1"}}
=end
    def sign_valid?(content)
      sign = content.delete('sign')
      calculate_sign = sign_paylinx(content, "i111HhkA0cHoYC29d9Z222OTYMAIzzz2T")
      return calculate_sign == sign
    end

  end
end