require File.join(File.dirname(__FILE__), 'environment')

configure do
  set :views, "#{File.dirname(__FILE__)}/views"
end

#use Rack::Auth::Basic, "Restricted Area" do |username, password|
  #[username, password] == ['hiyo', '2501']
#end

before do
  @aws_url = "http://aws-portal.amazon.com/gp/aws/developer/subscription/index.html?productCode=AmazonEC2"
end

error do
  e = request.env['sinatra.error']
  Kernel.puts e.backtrace.join("\n")
  'Application error'
end

get '/' do
  haml :index
end

get '/a/:id' do
  @aws = Aws.find(params[:id])

  b = Celerity::Browser.new(:resynchronize => true)
  b.goto(@aws_url)

  case @aws.registration.step
  when nil
    process_signup_page(b)
    process_register_page(b)

    if (b.hidden(:name, 'captchaId').exists? rescue false)
      # set captcha
      @aws.registration.step = "captcha-input"
      @aws.registration.captcha_url = "https://capi-na.ssl-images-amazon.com:443/#{b.hidden(:name, 'captchaId').value}"
      @aws.registration.captcha_at = Time.now
      @aws.save

      redirect "/a/#{@aws.id.to_s}/captcha"
    else
      handle_error(b, "captchaId not found")
      haml :fail
    end
  when 'captcha-input'
    process_login_page(b)

    if (b.hidden(:name, 'captchaId').exists? rescue false)
      if b.hidden(:name, 'captchaId').value.blank?
        handle_error(b, "captchaId is blank")
        haml :fail
      else
        # set captcha
        @aws.registration.step = "captcha-input"
        @aws.registration.captcha_url = "https://capi-na.ssl-images-amazon.com:443/#{b.hidden(:name, 'captchaId').value}"
        @aws.registration.captcha_at = Time.now
        @aws.save

        redirect "/a/#{@aws.id.to_s}/captcha"
      end
    else
      handle_error(b, "Expected to be on captcha page")
      haml :fail
    end
  when 'captcha-set'
    process_login_page(b)
    process_address_entry_page(b)

    if (b.text_field(:name, 'addCreditCardNumber').exists? rescue false)
      process_cc_entry_page(b)

      if (b.button(:name, 'get-billing-address-submit-button').exists? rescue false)
        process_cc_address_page(b)
      end

      if (b.link(:href, 'javascript:makeGetPhonePINRequest()').exists? rescue false)
        @aws.registration.step = "ec2-signup"
        @aws.save

        redirect "/a/#{@aws.id.to_s}"
      else
        handle_error(b, "Make call button not found on page")
        haml :fail
      end
    else
      @aws.registration.step = "captcha-input"
      @aws.save

      handle_error(b, "Expected to be on Credit Card Page")
      haml :fail
    end
  when 'ec2-signup'
    process_login_page(b)

    b.checkbox(:name => 'newReadAgreement').set
    b.button(:name => 'get-address-submit-button').click

    process_cc_entry_page(b)

    if (b.link(:href, 'javascript:makeGetPhonePINRequest()').exists? rescue false)
      process_call_pin_page(b)

      pin = b.div(:id, 'pin_block').text.gsub('Your PIN:', '').strip

      if pin.present?
        REDIS.set("#{@aws.registration.phone_number}_PIN", pin)

        puts "######REDIS#######"
        puts "PIN SET TO: #{REDIS.get("#{@aws.registration.phone_number}_PIN")}"
        puts "######REDIS#######"

        @aws.registration.call_pin = pin
        @aws.save

        sleep(60)

        b.button(:name, 'verification-complete-button').click

        if (b.button(:name, 'service-summary-submit-button').exists? rescue false)
          @aws.registration.step = "verify-activation"
          @aws.save

          b.buttons.first.click

          redirect "/a/#{@aws.id.to_s}"
        else
          handle_error(b, "Expected to be on Service Summary Page")
          haml :fail
        end
      else
        handle_error(b, "Pin was blank")
        haml :fail
      end
    else
      handle_error(b, "Expected to be on make call page")
      haml :fail
    end
  when "verify-activation"
    process_login_page(b)

    if (b.table(:index, 3).h1(:index, 1).exists? rescue false)
      if (b.table(:index, 3).h1(:index, 1).text == "XXX #{@aws.registration.email}")
        @aws.registration.step = "account-created"
        @aws.save

        redirect "/a/#{@aws.id}/getkeys"
      else
        handle_error(b, "Expected to find h1 on table 3 is XXX #{@aws.registration.email}")
        haml :fail
      end
    else
      @aws.registration.step = "ec2-signup"
      @aws.save

      handle_error(b, "Expected to be on Service summary page")
      haml :fail
    end
  when 'account-created'
    redirect "/a/#{@aws.id}/getkeys"
  end
end

get '/a/:id/captcha' do
  @aws = Aws.find(params[:id])

  haml :captcha
end

post '/a/:id/captcha' do
  @aws = Aws.find(params[:id])

  if params[:captcha_text]
    @aws.registration.step = "captcha-set"
    @aws.registration.captcha_text = params[:captcha_text]
    @aws.save
  end

  redirect "/a/#{@aws.id.to_s}"
end

get '/a/:id/pin' do
  @aws = Aws.find(params[:id])

  @aws.registration.call_pin
end

get '/new/a' do
  @aws = Aws.new

  @aws.save

  redirect "/"
end

get '/a/:id/getkeys' do
  @aws = Aws.find(params[:id])

  b = Celerity::Browser.new(:resynchronize => true)
  b.goto('http://aws-portal.amazon.com/gp/aws/developer/account/index.html?action=access-key')

  b.text_field(:name, 'email').value = @aws.registration.email
  b.text_field(:name, 'password').value = @aws.registration.password
  b.button(:id, 'signInSubmit').click

  keys = b.link(:id, /showAccessKey_(.*)/i).href.strip.to_s.scan(/javascript:showAccessKey\('(.{20})','(.{40})'\);/i).first
  account_id = b.span(:class => 'txtxxsm').text.scan(/(\d*)-(\d*)-(\d*)/i).join

  @aws.access_key_id = keys[0]
  @aws.secret_access_key = keys[1]
  @aws.account_id = account_id

  if @aws.save
    @aws.registration.step = "complete"
    @aws.registered = true

    @aws.save
  end

  body @aws.to_json.to_s
end

get '/a/:id/billing' do
  @aws = Aws.find(params[:id])
  @url = 'http://aws-portal.amazon.com/gp/aws/developer/account/index.html?ie=UTF8&action=activity-summary'

  b = Celerity::Browser.new(:resynchronize => true)
  b.goto(@url)

  process_login_page(b)

  b.table(:index, 4).td(:index, 2).text
end

private
  def handle_error(b, e)
    @b = b
    @error = e
  end

  def process_signup_page(b)
    b.text_field(:name, 'email').value = @aws.registration.email
    b.radio(:name, 'create').set
    b.button(:id, 'signInSubmit').click
  end

  def process_register_page(b)
    # Email & Password Register Page
    b.text_field(:name, 'customerName').value = @aws.registration.name
    b.text_field(:name, 'emailCheck').value = @aws.registration.email
    b.text_field(:name, 'password').value = @aws.registration.password
    b.text_field(:name, 'passwordCheck').value = @aws.registration.password
    b.button(:id, 'continue').click
  end

  def process_address_entry_page(b)
    # Address
    unless (b.button(:name, 'change-address-button').exists? rescue true)
      b.text_field(:name, 'Address1').value = @aws.registration.street
      b.text_field(:name, 'City').value = @aws.registration.city
      b.text_field(:name, 'State').value = @aws.registration.state
      b.text_field(:name, 'Zip').value = @aws.registration.zip_code
      b.text_field(:name, 'Phone').value = @aws.registration.phone_number
    end

    # Terms
    b.checkbox(:name => 'newReadAgreement').set

    # Fill in CAPTCHA
    b.hidden(:name, 'captchaId').value = @aws.registration.captcha_url.gsub('https://capi-na.ssl-images-amazon.com:443/', '')
    b.text_field(:name, 'captchaResponse').value = @aws.registration.captcha_text
    b.button(:name => 'get-address-submit-button').click
  end

  def process_login_page(b)
    b.text_field(:name, 'email').value = @aws.registration.email
    b.text_field(:name, 'password').value = @aws.registration.password
    b.button(:id, 'signInSubmit').click
  end

  def process_service_select_page(b)
    b.link(:href, 'http://aws.amazon.com/ec2').click
    b.link(:href, 'http://aws-portal.amazon.com/gp/aws/developer/subscription/index.html?productCode=AmazonEC2').click
  end

  def process_cc_entry_page(b)
    b.text_field(:name, 'addCreditCardNumber').value = @aws.registration.credit_card[:number]
    b.select_list(:name, 'newCreditCardMonth').set @aws.registration.credit_card[:month]
    b.select_list(:name, 'newCreditCardYear').set @aws.registration.credit_card[:year]
    b.text_field(:name, 'newCreditCardName').set @aws.registration.credit_card[:name]
    b.button(:name, 'get-credit-card-submit-button').click

    if (b.button(:name, 'get-billing-address-submit-button').exists? rescue false)
      process_cc_address_page(b)
    end
  end

  def process_cc_address_page(b)
    b.button(:name, 'get-billing-address-submit-button').click
  end

  def process_call_pin_page(b)
    b.link(:href, 'javascript:makeGetPhonePINRequest()').click

    b.wait
  end
