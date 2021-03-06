class ParseThemeService

  class << self
    def add_section html_content, promotions, shop
      discount_html = ""
      promotions.volume_amount.each do |promotion|
        promotion_detail = promotion.promotion_details
        promotion_html = promotion_detail.inject("") do |html, promotion|
          html += "<tr>
                    <td>#{promotion.qty.to_i}+</td>
                    <td><span class='saso-price'>#{promotion.value.to_i}% Off</span>
                  </tr>"
        end
        product_liquid_array = promotion.products.pluck(:product_shopify_id).join("|")

        discount_html += "{% assign myProductId_#{promotion.id} = '#{product_liquid_array}'  %}
                         {% if myProductId_#{promotion.id} contains product.id %}
                            <div class='saso-volumes'>
                              <div class='saso-volume-discount-tiers'>
                                <h4>Buy more, Save more!</h4>
                                <table class='saso-table'>
                                  <tbody>
                                    <tr>
                                      <th>Minimum Qty</th>
                                      <th>Discount</th>
                                      <!--<th>&nbsp;</th>-->
                                    </tr>
                                    #{promotion_html}
                                  </tbody>
                                </table>
                              </div>
                            </div>
                          {% endif %}"
      end


      # html_content.gsub!(discount_html, "")
      unless (html_content =~ /div class='saso-volumes'/).present?
        insert_point = html_content =~ /<div class="product-single__add-to-cart">/
        html_content.insert(insert_point, discount_html)
        html_content.gsub!("{% if section.settings.quantity_enabled %}", "{% if true %}")
      end
      return html_content
    end

    def add_discount_cart html_content, promotions, shop
      session = ShopifyAPI::Session.new(shop.shopify_domain, shop.shopify_token)
      ShopifyAPI::Base.activate_session(session)
      cart = ShopifyAPI::Asset.find('templates/cart.liquid')
      cart.value = cart.value.gsub("{% include 'vncpc' %}" , "")
      cart.save

      @promotion_html = ""
      @condition_product_id = []
      @assign_product_ids = []
      @alert_discount_html = ""
      promotions.volume_amount.each_with_index do |promotion, index|
        @condition_product_id << promotion.products.pluck(:product_shopify_id)
        product_liquid_array = (promotion.products.pluck(:product_shopify_id) << '0').join("|")
        # promotion_detail = promotion.promotion_details
        qty = promotion.promotion_details.map{|a| [a.qty.to_i, a.value.to_i] }.sort {|x,y| y <=> x }
        alert_discount = promotion.promotion_details.map{|a| [a.qty.to_i, a.value.to_i] }.sort {|x,y| x <=> y }
        @assign_product_ids << "{% assign myProductId_#{promotion.id} = '#{product_liquid_array}'  %}"
        @content = ""

        @discount_detail_list = ""
        qty.each_with_index do |detail_, index__|
          @discount_detail_list += "<div class='discount-tier'>"
          @discount_detail_list += "<span class='discount-info' style='float: left;text-transform: capitalize;'> #{detail_[0].to_i} or More Discount #{detail_[1].to_i}% </span>"
          @discount_detail_list += "{% if myProductId_#{promotion.id} contains item.product_id and item.quantity >= #{detail_[0].to_i} %}"
          @discount_detail_list += "<span class='discount-cost' style='color: red;font-weight: bold;float: right;margin-left: 10px;'> -{{ #{detail_[1].to_i} | times: item.line_price | divided_by: 100 | money }} </span>"
          @discount_detail_list += "{% endif %}"
          @discount_detail_list += "</div>"
        end

        qty.each_with_index do |detail, index_|
          @content += ((index.zero? && index_.zero?) ? "{% if myProductId_#{promotion.id} contains item.product_id and item.quantity >= #{detail[0].to_i} %}" : "{% elsif myProductId_#{promotion.id} contains item.product_id and item.quantity >= #{detail[0].to_i} %}")
          @content += "<span class='booster-cart-item-line-price' data-key='{{item.key}}' data-product='{{ item.product.id}}' data-item='{{ item.id}}' data-qty='{{item.quantity}}'>
                      <span class='original_price'>
                         Our Price: {{ item.line_price | money }}
                         {% assign original_total = item.line_price | plus: original_total  %}
                      </span>
                      <span class='discounted_price'>"
          @content += @discount_detail_list


          @content += "{% assign total = 100 | minus: #{detail[1].to_i} | times: item.line_price | divided_by: 100 | plus: total  %}
                       {% assign total_discount = #{detail[1].to_i} | times: item.line_price | divided_by: 100 | plus: total_discount  %}
                      </span>
                      <span class='after-discount-price'>
                       Subtotal: {{ 100 | minus: #{detail[1].to_i} | times: item.line_price | divided_by: 100 | money}}
                      </span>
                      </span>"
        end

        alert_discount.each_with_index do |detail, index_|
          @alert_discount_html += ((index.zero? && index_.zero?) ? "{% if myProductId_#{promotion.id} contains item.product_id and item.quantity < #{detail[0].to_i} %}" : "{% elsif myProductId_#{promotion.id} contains item.product_id and item.quantity < #{detail[0].to_i} %}")
          @alert_discount_html += "<span class='miskre-discount-note' data-id= {{item.id}}>Buy #{alert_discount[index_][0].to_i} to get #{alert_discount[index_][1].to_i}% off</span>"
        end
        @promotion_html +=  (@content.blank? ? "" :  @content)
      end

      compare_price = "<span class='compare_price'>
                       {% if item.product.compare_at_price > 0 %}
                         Retail Price: {{ item.product.compare_at_price | times: item.quantity | money }}
                          {% assign compare_price_total = item.product.compare_at_price | times: item.quantity | plus: compare_price_total  %}
                        {% else %}
                           {% assign compare_price_total = item.line_price | plus: compare_price_total  %}
                       {% endif %}
                      </span>"

      else_qty = "{% elsif true %}
                  <span class='booster-cart-item-line-price' data-key='{{item.key}}' data-product='{{ item.product.id}}' data-item='{{ item.id}}' data-qty='{{item.quantity}}'>{{ item.line_price | money }}</span>
                  {% assign total = item.line_price | plus: total  %}
                  {% assign original_total = item.line_price | plus: original_total  %}
                  {% endif %}"

      @alert_discount_html = @alert_discount_html.present? ? (@assign_product_ids.join("\n") + @alert_discount_html + "{% endif %}") : ""
      @promotion_html =  @assign_product_ids.join("\n") + compare_price + @promotion_html + else_qty

      @spend_amount_html = ""
      @alert_spend_amount_html = ""
      promotions.spend_amount.each_with_index do |promotion, index|
        qty = promotion.promotion_details.map{|a| [a.qty.to_i, a.value.to_i] }.sort {|x,y| y <=> x }
        alert_spend_qty = promotion.promotion_details.map{|a| [a.qty.to_i, a.value.to_i] }.sort {|x,y| x <=> y }
        qty.each_with_index do |detail, index_|
          @spend_amount_html += ((index.zero? && index_.zero?) ? "{% if total >= #{detail[0].to_i*100} %}" : "{% elsif total >= #{detail[0].to_i*100} %}")
          @spend_amount_html += "{% assign total_discount = #{detail[1].to_i} | times: total | divided_by: 100 | plus: total_discount  %}
                                {% assign final_price = 100 | minus: #{detail[1].to_i} | times: total | divided_by: 100  %}
                                <span class='discount-spend-amount'>Discount #{detail[1].to_i}% = {{ #{detail[1].to_i} | times: total | divided_by: 100 | money }}</span>
                                <span class='wh-cart-total' data-original={{ original_total }}>{{ 100 | minus: #{detail[1].to_i} | times: total | divided_by: 100 | money }}</span>"
        end
        alert_spend_qty.each_with_index do |detail, index_|
          @alert_spend_amount_html += ((index.zero? && index_.zero?) ? "{% if total < #{detail[0].to_i*100} %}" : "{% elsif total < #{detail[0].to_i*100} %}")
          @alert_spend_amount_html += '<script type="text/javascript">' +
              'script = document.createElement("script");
                                        script.type = "text/javascript";
                                        script.src = "https://ajax.googleapis.com/ajax/libs/jquery/1.6.4/jquery.min.js";
                                        document.head.appendChild(script);
                                        script.onload = function() {' +
              'var html = "' + "<div id='miskre-notification-bar' style='display: block;'>Spend " + "{{ #{detail[0].to_i*100} | money }}" + " to get #{detail[1].to_i}% off</div>" + '";' +
              '$("main").prepend(html);' +
              '};' +
              '</script>'
        end

        @success_spend_amount_html = if @alert_spend_amount_html.present?
                                       "{% elsif total > #{alert_spend_qty.last[0].to_i*100} %}" +
                                           '<script type="text/javascript">' +
                                           'script = document.createElement("script");
                                        script.type = "text/javascript";
                                        script.src = "https://ajax.googleapis.com/ajax/libs/jquery/1.6.4/jquery.min.js";
                                        document.head.appendChild(script);
                                        script.onload = function() {' +
                                           'var html = "' + "<div id='miskre-notification-bar' style='display: block;'>Congrats! You’ve got "  + "#{alert_spend_qty.last[1].to_i}% off</div>" + '";' +
                                           '$("main").prepend(html);' +
                                           '};' +
                                           '</script>'
                                     end
      end



      @alert_spend_amount_html = @alert_spend_amount_html.present? ? (@alert_spend_amount_html +  @success_spend_amount_html + "{% endif %}") : ""

      @spend_amount_html = @spend_amount_html.present? ? @spend_amount_html : '<span class="wh-cart-total" data-original={{ original_total }}>{{ total| money }}</span>'

      if @spend_amount_html != '<span class="wh-cart-total" data-original={{ original_total }}>{{ total| money }}</span>'
        @else_spend_amount = "{% elsif true %}
                          {% assign final_price = total  %}
                          <span class='wh-cart-total no-discount' data-original={{ original_total }}>{{ total | money }}</span>
                          {% endif %}"
      else
        @else_spend_amount = "{% assign final_price = total  %}"
      end

      total_qty = '<span class="cart__subtotal"><span class="wh-original-cart-total">{{ total | money }}</span>' + (@spend_amount_html + @else_spend_amount) + '</span><div class="additional-notes">YOU SAVE {{ compare_price_total | minus: final_price | money}}</div></span>' + @alert_spend_amount_html
      if @promotion_html
        html_content.prepend("{% include 'vncpc' %}")
        html_content.prepend("{% assign total = 0 %}")
        html_content.prepend("{% assign original_total = 0 %}")
        html_content.prepend("{% assign total_discount = 0 %}")
        html_content.prepend("{% assign compare_price_total = 0 %}")
        html_content.prepend("{% assign final_price = 0 %}")
        # html_content.gsub!("<span class='booster-cart-item-line-price' data-key='{{item.key}}'>{{ item.line_price | money }}</span>", @promotion_html)
        html_content.gsub!("{{ item.line_price | money }}", @promotion_html)
        html_content.gsub!('<p class="cart__subtotal"><span id="bk-cart-subtotal-price">{{ cart.total_price | money }}</span></p>', total_qty)
        # html_content.gsub!('<p class="cart__subtotal"><span id="bk-cart-subtotal-price"><span class="wh-original-cart-total">{{ cart.total_price | money }}</span><span class="wh-cart-total"></span><div class="additional-notes"><span class="wh-minimums-note"></span><span class="wh-extra-note"></span></div></span></p>', total_qty)
      end

      unless (html_content =~ /<input id="discount_input" type="hidden" name="discount" value="">/).present?
        insert_point_2 = html_content =~ /<form action="\/cart" method="post" novalidate class="cart">/
        if insert_point_2
          insert_point_2 += ('<form action="cart" method="post" novalidate class="cart">'.size + 1)
          html_content.insert(insert_point_2, '<input id="discount_input" type="hidden" name="discount" value="">')
        end
      end

      unless (html_content =~ /{{ item.product.title }}/).nil?
        insert_point_3 = html_content =~ /{{ item.product.title }}/
        if insert_point_3
          insert_point_3 += ("{{ item.product.title }}".size + 1)
          html_content.insert(insert_point_3, @alert_discount_html)
        end
      end
      return html_content
    end

    def add_snippet shop
      session = ShopifyAPI::Session.new(shop.shopify_domain, shop.shopify_token)
      ShopifyAPI::Base.activate_session(session)
      script_content = "<style type=\"text/css\">\ndiv#miskre-notification-bar{\n  font-size: 110%;\n  background-color: #a1c65b;\n  padding: 12px;\n  color: #ffffff;\n  font-family: inherit;\n  z-index: 9999999999999;\n  display: block;\n  left: 0px;\n  width: 100%;\n  margin: 0px;\n  margin-bottom:20px;\n  text-align: center;\n  text-transform: none;\n}\n</style>\n\n{% if template contains 'cart' %}\n\n\t<script type=\"text/javascript\">\n      document.addEventListener(\"DOMContentLoaded\", function(event) { \n          document.getElementsByClassName(\"grid__item large--five-sixths push--large--one-twelfth\")[0].innerHTML = null;\n        });\n      \n    </script>\n\t{% section 'cart-template-miskre-discount' %}\n\t<script type=\"text/javascript\">\n      \n      function reqJquery(onload) {       \n        if(typeof jQuery === 'undefined' || (parseInt(jQuery.fn.jquery) === 1 && parseFloat(jQuery.fn.jquery.replace(/^1\\./,'')) < 10)){\n          var head = document.getElementsByTagName('head')[0];\n          var script = document.createElement('script');\n          var cookie = document.createElement('script');\n          script.src = ('https:' == document.location.protocol ? 'https://' : 'http://') + 'ajax.googleapis.com/ajax/libs/jquery/3.3.1/jquery.min.js';;\n          script.type = 'text/javascript';\n          script.onload = script.onreadystatechange = function() {\n            if (script.readyState) {\n              if (script.readyState === 'complete' || script.readyState === 'loaded') {\n                script.onreadystatechange = null;\n                onload(jQuery.noConflict(true));\n              }\n            }\n            else {\n              onload(jQuery.noConflict(true));\n            }\n          };\n          cookie.src = ('https:' == document.location.protocol ? 'https://' : 'http://') + 'cdnjs.cloudflare.com/ajax/libs/jquery-cookie/1.4.1/jquery.cookie.min.js';;\n          cookie.type = 'text/javascript';\n          \n          head.appendChild(script);\n          head.appendChild(cookie);\n        }else {\n          onload(jQuery);\n        }\n      }\n\t\t\n  \n    reqJquery(function($){\n      \t\n      \t$( document ).ready(function() {\n          document.getElementsByClassName(\"grid__item large--five-sixths push--large--one-twelfth\")[0].innerHTML = null;\n          $(\".discounted_price\").each(function( index ) {\n            \n            $(this).find(\".discount-cost\").first().addClass(\"discount-tier\");\n            $(this).find(\".discount-cost\").first().removeClass(\"discount-cost\");\n            $(this).find(\".discount-cost\").remove();\n          });\n          $(\".wrapper\").css({\"max-width\": \"60%\", \"margin\": \"0 auto\"});\n          $(\".wh-original-cart-total\").css({\"text-decoration\": \"line-through\", \"display\": \"block\"});\n          $(\".original_price\").css({\"text-decoration\": \"none\", \"display\": \"block\",\"text-transform\": \"capitalize\"});\n          $(\".discounted_price\").css({\"color\": \"#1be41b\",\"font-weight\": \"normal\", \"display\": \"inline-block\", \"font-size\": \"13px\"});\n          $(\".after-discount-price\").css({\"color\": \"#1be41b\", \"font-weight\": \"bold\",\"text-transform\": \"capitalize\"});\n          $(\".discount-spend-amount\").css({\"color\": \"#1be41b\",\"font-weight\": \"normal\"});\n          $(\".wh-cart-total\").css({\"font-weight\": \"bold\", \"color\": \"#1be41b\", \"display\": \"block\"});\n          $(\".no-discount\").css({\"font-weight\": \"bold\"});\n          $(\".miskre-discount-note\").css({\"display\": \"block\", \"font-weight\": \"bold\", \"color\": \"#0078bd\", \"font-size\": \"100%\"});\n          $(\".compare_price\").css({\"display\": \"block\",\"text-transform\": \"capitalize\"});     \n          $(\".additional-notes\").css({\"color\": \"#00ff24\", \"font-size\": \"21px\", \"margin-top\": \"20px\"});\n          if ($(\".wh-cart-total\").text() == $(\".wh-original-cart-total\").text()) {\n            $(\".wh-original-cart-total\").remove();\n            $(\".wh-cart-total\").css({ \"color\": \"black\"});\n          }\n          $(\".discount-cos\")[0].addClass(\"discounted\");\n          $(\"grid\").find(\"#miskre-close-notification\").css({\"float\": \"right!important\", \"font-weight\": \"bold\", \"height\": \"0\", \"overflow\": \"visible\", \"cursor\": \"pointer\", \"margin-right\": \"2em\"});\n          $(\"grid\").find(\"#miskre-notification-bar\").css({\"font-size\": \"110%\", \"background-color\": \"#a1c65b\", \"padding\": \"12px\", \"color\": \"#ffffff\", \"font-family\": \"inherit\", \"z-index\": \"9999999999999\", \"display\": \"block\", \"left\": \"0px\", \"width\": \"100%\", \"margin\": \"0px\", \"margin-bottom\": \"20px\",\"text-align\": \"center\", \"text-transform\": \"none\"});\n          $( \".cart__product-qty\" ).each(function() {\n            $(this).on(\"change\", function(){              \t\n                $(\".update-cart\").click();\n              });\n          });\n        });\n      \t\n      \t\n          \n      \tfunction addDiscount(code, button) {          \n          $(\"#discount_input\").val(code);          \n          submitCart(button);\n       \t}\n    \t\n        function submitCart(button) {\n          \n          $(button).delay(4000).click();\n         }\n          \n      \t     \n      \tvar create_discount = false;\n      \t\t\n        var checkout_selectors = [\"input[name='checkout']\", \"button[name='checkout']\", \"[href$='checkout']\", \"input[name='goto_pp']\", \"button[name='goto_pp']\", \"input[name='goto_gc']\", \"button[name='goto_gc']\", \".additional-checkout-button\", \".google-wallet-button-holder\", \".amazon-payments-pay-button\"];\n        \n      \tcheckout_selectors.forEach(function(selector) {\n\n          var els = document.querySelectorAll(selector);\n\n          for (var i = 0; i < els.length; i++) {\n            var el = els[i];           \n            \n            \n            el.addEventListener(\"click\", function submitCart(ev) {\n              if (create_discount == false){\n              \tev.preventDefault();\n              }\n              \n              \n              var button = $(this)\n              try {\n                var self = $('#cart_form');\n                productArray = []\n                itemDetails = []\n                qty = []\n                $(\".booster-cart-item-line-price\").each(function() {\n                    productArray.push($(this).data(\"product\"));\n                  \titemDetails.push($(this).data(\"item\"));\n                  \tqty.push($(this).data(\"qty\"));\n                  \n                });\n                parameters = { original_price: $(\".wh-cart-total\").data(\"original\"), discount_price: $(\".wh-cart-total\").text(), product_array: productArray, items_detail: itemDetails, qty: qty};\n                if (create_discount == false){\n                  $.ajax({\n                    url: \"https://miskre-discount-app.herokuapp.com/discount_cart\",\n                    type: \"POST\",\n                    data: parameters,\n                    dataType: \"json\",\n                    success: function(response){\n                      create_discount = true;\n                      if (response.discount_code != false) {                        \n                       addDiscount(response.discount_code, button);\n                      } else{\n                        $(button).delay(4000).click();\n                      }\n                    },\n                    error: function(response){\n                      console.log(response);\n                    }\n                  });\n                }\n                return true;\n              }\n              catch(err) {\n                 console.log(err);\n              }\n            }, false);\n          }\n\n            })\n               \n    })\n      \n\n      \n\n</script>\n{% endif %}\n\n"
      theme = ShopifyAPI::Asset.find('layout/theme.liquid')
      html_theme_value = theme.value
      unless (html_theme_value =~ /{% include 'miskre-discount' %}/).present?
        insert_point = html_theme_value =~ /{{ content_for_layout }}/
        if insert_point
          insert_point += ("{{ content_for_layout }}".size + 1)
          html_theme_value.insert(insert_point, "{% include 'miskre-discount' %}")
          theme.value = html_theme_value
          theme.save
        end
      end
      return script_content
    end
  end
end