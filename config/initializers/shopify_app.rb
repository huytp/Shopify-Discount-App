ShopifyApp.configure do |config|
  config.application_name = "My Shopify App"
  config.api_key = "#{ENV['SHOPIFY_API_KEY']}"
  config.secret = "#{ENV['SHOPIFY_SECRET']}"
  config.scope = "read_checkouts, write_checkouts, read_orders, write_orders, read_products, write_products, write_shipping, read_fulfillments, write_fulfillments, read_script_tags, write_script_tags, read_themes, write_themes, read_price_rules, write_price_rules"
  config.embedded_app = true
  config.after_authenticate_job = false
  config.session_repository = Shop
  config.webhooks = [
    {topic: 'app/uninstalled', address: 'http://1a3e9a91.ap.ngrok.io/webhooks/app_uninstalled', format: 'json'},
  ]
end
