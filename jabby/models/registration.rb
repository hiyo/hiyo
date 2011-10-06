class Registration
  include Mongoid::Document

  field :step,          :type => String

  field :name,          :type => String,  :default => NameGen.generate
  field :email,         :type => String,  :default => "#{rand(10000000)}@emaildomain.org"
  field :password,      :type => String,  :default => "hiyobotnetT1000"

  field :street,        :type => String,  :default => '1 Infinite Loop'
  field :city,          :type => String,  :default => 'Cupertino'
  field :zip_code,      :type => String,  :default => '95014'
  field :state,         :type => String,  :default => 'CA'
  field :phone_number,  :type => String,  :default => '15551231234'# Twillio virtual number

  field :captcha_url,   :type => String
  field :captcha_text,  :type => String
  field :captcha_at,    :tyep => DateTime
  
  field :call_pin,      :type => Integer

  embedded_in :aws, :inverse_of => :registration

  validates :email,
            :presence => true,
            :uniqueness => true,
            :allow_blank => false
  validates_uniqueness_of :email
  validates :password,
            :presence => true,
            :allow_blank => false

  # Visa giftcard
  def credit_card
    {
      :number => '',
      :month => '',
      :year => '',
      :name => ''
    }
  end
end
