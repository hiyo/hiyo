module NameGen
  @last_names = (File.open("#{File.dirname(__FILE__)}/dist.all.last.de", "rb") {|f| f.read}).scan(/^\w+/).map
  @male_names = (File.open("#{File.dirname(__FILE__)}/dist.male.first", "rb") {|f| f.read}).scan(/^\w+/).map
  @female_names = (File.open("#{File.dirname(__FILE__)}/dist.female.first", "rb") {|f| f.read}).scan(/^\w+/).map

  def self.generate
    if rand() < 0.46 then
      first = @male_names[rand(@male_names.size)]
    else
      first = @female_names[rand(@female_names.size)]
    end

    "#{first} #{@last_names[rand(@last_names.size)]}"
  end
end
