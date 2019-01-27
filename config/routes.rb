Rails.application.routes.draw do
  # 仅做示例用途
  #---------------Paylinx----------------
  post 'wechat_paylinx', to: "my_orders#wechat_paylinx" # Paylinx 支付页(负责显示付款二维码)
  post 'paylinx_notify', to: "my_orders#paylinx_notify" # Paylinx 回调
  get "query_paylinx_info", to: "my_orders#query_paylinx_info" # Paylinx 支付页, Javascript 3秒轮询一次订单状态的接口

end