class Aws
  include Mongoid::Document
  include Mongoid::Timestamps

  field :account_id,          :type => String
  field :access_key_id,       :type => String
  field :secret_access_key,   :type => String
  field :registered,          :type => Boolean, :default => false
  field :email,               :type => String

  embeds_one :registration

  validates :account_id,
            :length => {:is => 12},
            :allow_blank => false,
            :if => Proc.new { |a| a.registered }
  validates :access_key_id,
            :length => {:is => 20},
            :allow_blank => false,
            :if => Proc.new { |a| a.registered }
  validates :secret_access_key,
            :length => {:is => 40},
            :allow_blank => false,
            :if => Proc.new { |a| a.registered }
  validates :email,
            :presence => true,
            :uniqueness => true,
            :allow_blank => false
  validates :registration,
            :presence => true,
            :unless => Proc.new { |a| a.registered }
  validates_associated :registration, :unless => Proc.new { |a| a.registered }

  before_validation(:on => :create) do
    self.registration = Registration.new
    self.email = registration.email
  end
end
