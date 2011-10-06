class CallsController < ApplicationController
  def cat
    
  end

  def incoming
    sleep(11)

    @to = params["To"].to_s.scan(/\d+/i).join

    @pin = REDIS.get("#{@to}_PIN")

    logger.info "#########PARAMS##########"
    logger.info "To: #{@to}"
    logger.info "Pin: #{@pin}"
    logger.info "#########PARAMS##########"

    if @pin.present?
      resp = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
        xml.Response do
          xml.Say("Hello")
          xml.Pause(:length => "15")
          @pin.split("").each do |i|
            xml.Say("#{i}")
            xml.Pause(:length => "1")
          end
          xml.Pause(:length => "7")
          xml.Hangup
        end
      end
    else
      resp = Nokogiri::XML::Builder.new(:encoding => 'UTF-8') do |xml|
        xml.Response do
          xml.Hangup
        end
      end
    end

    logger.info "#########TiML##########"
    logger.info resp.to_xml
    logger.info "#########TiML##########"

    respond_to do |format|
      format.any do
        render :xml => resp
      end
    end

  end
end
