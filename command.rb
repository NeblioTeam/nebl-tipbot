#!/usr/bin/ruby
require 'bitcoin-client'
require 'net/http'
require 'sinatra'
require 'json'
require 'nokogiri'
require 'open-uri'

Dir['./coin_config/*.rb'].each {|file| require file }
require './bitcoin_client_extensions.rb'
class Command
  attr_accessor  :result, :action, :user_name, :icon_emoji , :channel
  ACTIONS = %w(leaderboard balance chart deposit tip withdraw about price help hi commands stats)
  def initialize(slack_params)
    @coin_config_module = Kernel.const_get ENV['COIN'].capitalize
    text = slack_params['text']
    @params = text.split(/\s+/)
    raise "NEBLIO IS THE BEST" unless @params.shift == slack_params['trigger_word']
    @user_name = slack_params['user_name']
    @user_id = slack_params['user_id']
    @action = @params.shift
    @result = {}
    @price = `ruby fiat.rb `
    @sh = `./disp.sh`
    end

 def perform
    if ACTIONS.include?(@action)
      self.send("#{@action}".to_sym)
    else
      raise @coin_config_module::PERFORM_ERROR
    end
  end

  def client
    @client ||= Bitcoin::Client.local
  end

 def balance
    balance = client.getbalance(@user_id)
    checkprice = open( "https://coinmarketcap.com/currencies/neblio/")
    document2 = Nokogiri::HTML(checkprice)
    priceusd = document2.xpath("//*[@id="quote_price"]/span[1]").inner_html
    pricei = priceusd.to_i
    x = ((balance*pricei.to_f).round(3)).to_s

    @result[:text] = "<@#{@user_id}> #{@coin_config_module::BALANCE_REPLY_PRETEXT} #{balance}#{@coin_config_module::CURRENCY_ICON} ≈ $#{x} "
    if balance > @coin_config_module::WEALTHY_UPPER_BOUND
      @result[:text] += @coin_config_module::WEALTHY_UPPER_BOUND_POSTTEXT
      @result[:icon_emoji] = @coin_config_module::WEALTHY_UPPER_BOUND_EMOJI
    elsif balance > 0 && balance < @coin_config_module::WEALTHY_UPPER_BOUND
      @result[:text] += @coin_config_module::BALANCE_REPLY_POSTTEXT
    end
  end
        def chart
 @result[:attachments] = [{
      title: "Neblio Price Chart",
      title_link: "https://coinmarketcap.com/currencies/neblio/#charts",
      color: "#0092ff",
      footer: "https://coinmarketcap.com/",
      footer_icon: "https://files.coinmarketcap.com/static/img/coins/16x16/neblio.png",
      attachment_type: "default",
}]
end

   def deposit
         @result[:text] = "<@#{@user_id}> #{@coin_config_module::DEPOSIT_PRETEXT} #{user_address(@user_id)} #{@coin_config_module::DEPOSIT_POSTTEXT} :neblio:"
        end

 def tip
    user = @params.shift
    raise @coin_config_module::TIP_ERROR_TEXT unless user =~ /<@(U.+)>/

    target_user = $1
    set_amount
    tx = client.sendfrom @user_id, user_address(target_user), @amount

    @result[:text] = "#{@coin_config_module::TIP_PRETEXT} <@#{@user_id}> -> <@#{target_user}> #{@amount}#{@coin_config_module::CURRENCY_ICON}"
    @result[:attachments] = [{
      fallback:"<@#{@user_id}> -> <@#{target_user}> #{@amount}NEBL :neblio:",
      color: "#ED1B24",
      fields: [{
        title: "Tipping initiated of #{@amount} NEBL :neblio:",
        value: "http://explorer.nebl.io/tx/#{tx}",
        short: false
      },{
        title: "Tipper",
        value: "<@#{@user_id}>",
        short: true
     },{
        title: "Recipient",
        value: "<@#{target_user}>",
        short: true
        }]
    }]
  end

  alias :":neblio:" :tip


  def withdraw
    address = @params.shift
    set_amount
    tx = client.sendfrom @user_id, address, @amount
    @result[:text] = "#{@coin_config_module::WITHDRAW_TEXT} <@#{@user_id}> -> #{address} #{@amount}#{@coin_config_module::CURRENCY_ICON} "
    @result[:text] += " (<#{@coin_config_module::TIP_POSTTEXT1}#{tx}#{@coin_config_module::TIP_POSTTEXT2}>)"
    @result[:icon_emoji] = @coin_config_module::WITHDRAW_ICON
  end

 private

  def set_amount
    amount = @params.shift
    @amount = amount.to_f
    randomize_amount if (@amount == "random")

    raise @coin_config_module::TOO_POOR_TEXT + @coin_config_module::FEE unless available_balance >= @amount + 0.0001
    raise @coin_config_module::NO_PURPOSE_LOWER_BOUND_TEXT if @amount < @coin_config_module::NO_PURPOSE_LOWER_BOUND
  end

  def randomize_amount
    lower = [1, @params.shift.to_f].min
    upper = [@params.shift.to_f, available_balance].max
    @amount = rand(lower..upper)
    @result[:icon_emoji] = @coin_config_module::RANDOMIZED_EMOJI
  end

  def available_balance
     client.getbalance(@user_id)
  end

  def user_address(user_id)
     existing = client.getaddressesbyaccount(user_id)
    if (existing.size > 0)
      @address = existing.first
    else
      @address = client.getnewaddress(user_id)
    end
  end

 def price
        @result[:text] = "#{@coin_config_module::PRICE_PRE}#{@sh} BTC :bitcoin:"
        @result[:text] += " ≈ #{@price}"
end


def leaderboard
end



def help

@result[:text] = @coin_config_module::HELP
end

def hi

@result[:text] = " #{@coin_config_module::HI} <@#{@user_id}> #{@coin_config_module::GREETING}"
end

def about
@result[:text] =  "#{@coin_config_module::ABOUT}: #{@coin_config_module::ABOUT2} "
end
 def commands

    @result[:text] = "#{ACTIONS.join(', ' )}"
  end

 def stats
	 checkprice2 = open( "https://coinmarketcap.com/currencies/neblio/")
	 document3 = Nokogiri::HTML(checkprice2)
	 position = document3.xpath("/html/body/div[2]/div/div[1]/div[4]/ul/li[1]/span[2]").inner_html
	 volume = document3.xpath("/html/body/div[2]/div/div[1]/div[4]/div[2]/div[2]/div/span[1]/span[1]").inner_html
	 marketcap = document3.xpath("/html/body/div[2]/div/div[1]/div[4]/div[2]/div[1]/div/span[1]/span[1]").inner_html
	 
	 volume2 =  volume.gsub(/\s+/, "")
	 marketcap2 = marketcap.gsub(/\s+/, "")
	 position2 = position.gsub(/\s+/, "")
	 
	@result[:text] = "NEBL :neblio: is #{@price}, #{position2} with a Market Cap of $#{marketcap2} and a 24Hr Volume of $#{volume2}"

end


end


