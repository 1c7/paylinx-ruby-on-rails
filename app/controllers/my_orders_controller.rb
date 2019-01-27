class MyOrdersController < ApplicationController
    def wechat_paylinx
        # TODO: 此处插入你自己的业务逻辑：创建订单

        @my_order = MyOrder.find(id)
        # 商户订单号，须确保商户系统内唯一
        out_trade_no = @my_order.order_no
        # 订单金额, 货币: AUD, 单位: 分
        # TODO: Paylinx 要求每次最少 1.30 澳元，所以为了测试这里就写 131
        total_fee_in_AUD_in_cent = 131
        # 交易说明
        body = 'body'
        # 支付通知URL
        notify_url = "https://#{request.host}/paylinx_notify"

        # 发请求给 Paylinx 的 "Wechat - 创建交易" 接口
        paylinx = Paylinx::PaylinxService.new
        result_xml = paylinx.create_qr_code_payment(out_trade_no, total_fee_in_AUD_in_cent, body, notify_url)

        # 解析 XML 变成 hash
        @result_hash = Hash.from_xml(result_xml)
        Rails.logger.info(@result_hash)
        # 举例:
=begin
{"xml"=>
  {"mch_id"=>"11112222",
   "store_id"=>"",
   "nonce_str"=>"gyy0rz9cypnk32k3yatgsl7z3dzws2zi",
   "notify_url"=>"https://localhost/royalpay_notify",
   "out_trade_no"=>"WX-Paylinx1548586784915",
   "body"=>"body",
   "spbill_create_ip"=>"192.168.5.25",
   "total_fee"=>"2300",
   "fee_type"=>"AUD",
   "trade_type"=>"NATIVE",
   "sign"=>"E6F9089E9BCA220A7A27996CCC590C20",
   "prepay_id"=>"wx271859474034871459ee42351903998739",
   "code_url"=>"weixin://wxpay/bizpayurl?pr=HRpVMOP",
   "paylinx_order_no"=>"20190127185946152660136175",
   "return_code"=>"SUCCESS",
   "return_msg"=>"OK",
   "result_code"=>"SUCCESS"}
}
=end
        # TODO: 把信息存入数据库
        # 比如我这里写的是: 
        # @paylinx_record = PaylinxPayment.new
        # @paylinx_record.prepay_id = @result_hash['xml']['prepay_id']
        # @paylinx_record.code_url = @result_hash['xml']['code_url']
        # @paylinx_record.order_no = @result_hash['xml']['paylinx_order_no']
        # @paylinx_record.my_order_id = @my_order.id
        # @paylinx_record.save

        # 生成二维码给前端显示
        @qr = RQRCode::QRCode.new(@paylinx_record.code_url, :size => 5, :level => :h )
    end

    # def paylinx_notify 接收 Paylinx 的支付回调, 并进行处理
    # 文档: http://paylinx.cn/doc/index.html#api-_footer
=begin
因为 Paylinx 的文档有些弱智，这里备份一下我当前这个时间点，"支付通知回调"文档是怎么说的(文档版本: 0.1.0)：

支付通知回调
先取到系统发送过来的回调数据：

$data = file_get_contents( 'php://input' );

解析数据成XML

$xml = simplexml_load_string( $data );

将XML转成数组，去除数组中键名为sign的元素，再按照概要中讲到的签名方式生成sign，用自己生成的sign与数组中的sign对比，如果相同则数据来源是正确的。

接下来判断数组中的result_code是否等于SUCCESS，如果等于则表示交易已经完成支付，接下来商户可以自行处理各自的业务逻辑，最后输出SUCCESS或FAILD
=end
    def paylinx_notify
      # 第1步: 验证签名
      raw_xml = request.raw_post()
      hash = Hash.from_xml(raw_xml)
      # hash 举例:
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
   "sign"=>"8FF02E09AD592B22842A227D945224B1"}
}
=end
      paylinx = Paylinx::PaylinxService.new
      valid = paylinx.sign_valid?(hash['xml']) # 返回 Boolean 代表是否合法
      # 不合法直接 FAILD
      unless valid
        render plain: 'FAILD'
        return
      end
      # 不成功直接 FAILD
      if hash['xml']['result_code'] != 'SUCCESS'
        render plain: 'FAILD'
        return
      end

      # 第2步: 如果支付成功，处理我们自己的业务逻辑, 并返回 'SUCCESS'
      # 通过 out_trade_no 找订单
      order_no = hash['xml']['out_trade_no']
      orders_collection = MyOrder.where(order_no: order_no)
      unless orders_collection.exists?
        Rails.logger.warn("---Paylinx 回调，签名合法，但无法通过订单号找到 MyOrder 记录，这不应该发生, 请查看并解决此问题---")
        Rails.logger.warn("时间: #{Time.zone.now}")
        Rails.logger.warn("raw 请求是")
        Rails.logger.warn(request.raw_post())
        Rails.logger.warn("hash 是")
        Rails.logger.warn(hash)
        Rails.logger.warn("---调试信息结束---")
        render plain: "FAILD"
        return
      end

      # 如果找到的订单数量超过1条，说明有问题，不应该这样
      if orders_collection.size > 1
        Rails.logger.warn("---Paylinx 回调，签名合法，但居然找到了1条以上的 MyOrder 记录，这不应该发生, 请查看并解决此问题---")
        Rails.logger.warn("时间: #{Time.zone.now}")
        Rails.logger.warn("raw 请求是")
        Rails.logger.warn(request.raw_post())
        Rails.logger.warn("hash 是")
        Rails.logger.warn(hash)
        Rails.logger.warn("---调试信息结束---")
        render plain: "FAILD"
        return
      end

      # 修改订单状态为已支付
      single_record = orders_collection.first
      single_record.order_state = "paid"
      if single_record.save
        render plain: 'SUCCESS'
        return
      else
        render plain: 'FAILD'
        return
      end
    rescue StandardError => e
      # 如果因为什么奇怪的问题出错了
      Rails.logger.info(request.raw_post()) # 把请求体记录下来
      Rails.logger.error("Paylinx 支付回调发生错误, 请尽快检查, 时间: #{Time.zone.now}")
      Rails.logger.error(e)
      render plain: "FAILD"
      return
    end

    # 查询通过 Paylinx 支付的订单信息
    def query_paylinx_info
      unless params.has_key?(:order_id)
        render json: {status: 4, message: '必须传入 order_id 参数'}
        return
      end
      order_id = params[:order_id]
      order = MyOrder.find_by_id(order_id)
      unless order
        render json: {status: 2, message: "找不到 id 为 #{order_id} 的订单"}
        return
      end
      if order.user_id != current_user.id
        render json: {status: 3, message: '只能查自己的订单'}
        return
      end
      respond_to do |format|
        format.json { render json: { order_state: order.order_state } }
      end
    end
end
