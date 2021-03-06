# t.string   "chinese",    limit: 255
# t.string   "english",    limit: 255
# t.datetime "created_at",             null: false
# t.datetime "updated_at",             null: false

class Block < ActiveRecord::Base
  validates_presence_of :chinese, :english
  validates_uniqueness_of :chinese, :english
  has_one :balance, class_name:'Balance',primary_key:'english', foreign_key:'block'
  has_many :tickers, class_name:'BlockTicker',foreign_key:'block_id'
  has_many :orders, class_name:'PendingOrder',primary_key:'english', foreign_key:'block'

  self.per_page = 10
  scope :named, ->{order(english: :asc)}

  def self.generate_md5(time)
    sign_string = "#{Settings.btc_key}_#{Settings.btc_id}_#{Settings.btc_secret}_#{time}"
    sign = Digest::MD5.hexdigest(sign_string)
  end

  def full_name
    "[#{self.english}]#{self.chinese}"
  end

  def three_day_minimum
    if self.interval_historical(3).count > 0
      return self.interval_historical(3).map{|x| x.last_price}.min
    end
    return 0
  end

  def three_day_maximun
    if self.interval_historical(3).count > 0
      return self.interval_historical(3).map{|x| x.last_price}.max
    end
    return 0
  end

  def yesterday_minimum
    if self.interval_historical(1).count > 40
      return self.interval_historical(1).map{|x| x.last_price}.min
    end
    return 0
  end

  def yesterday_maximun
    if self.interval_historical(1).count > 40
      return self.interval_historical(1).map{|x| x.last_price}.max
    end
    return 0
  end

  def minimum_24h
    if self.tickers.last(48).count > 0
      return self.tickers.last(48).map{|x| x.last_price}.min
    end
    return 0
  end

  def maximun_24h
    if self.tickers.last(48).count > 0
      return self.tickers.last(48).map{|x| x.last_price}.max
    end
    return 0
  end

  def interval_historical(number)
    today = Date.current.to_s
    number_day = (Date.current - number.day).to_s
    self.tickers.where('that_date >= ? and that_date < ?',number_day,today)
  end

  def day_historical(number)
    number_day = (Date.current - number.day).to_s
    self.tickers.where('that_date >= ? and that_date <= ?',number_day,number_day)
  end

  def ma5_quotes
    self.tickers.last(5).map {|x| x.last_price }.sum / 5
  end

  def continuous_decline?
    one_line_max = self.day_historical(1).map{|x| x.last_price}.max || 0
    two_line_max = self.day_historical(2).map{|x| x.last_price}.max || 0
    one_line_min = self.day_historical(1).map{|x| x.last_price}.min || 0
    two_line_min = self.day_historical(2).map{|x| x.last_price}.min || 0
    return true if one_line_max < two_line_max && one_line_min < two_line_min
    return false
  end

  def continuous_rise?
    one_line_max = self.day_historical(1).map{|x| x.last_price}.max || 0
    two_line_max = self.day_historical(2).map{|x| x.last_price}.max || 0
    one_line_min = self.day_historical(1).map{|x| x.last_price}.min || 0
    two_line_min = self.day_historical(2).map{|x| x.last_price}.min || 0
    return true if one_line_max > two_line_max && one_line_min > two_line_min
    return false
  end

  def today_had_buy?
    return true if self.orders.where("created_at >= ? and business = ?",Time.now.beginning_of_day,'1').count > 0
    false
  end

  def today_had_buy_count(sum_count)
    return true if self.orders.where("created_at >= ? and business = ?",Time.now.beginning_of_day,'1').count >= sum_count
    false
  end

  def today_buy_interval(interval)
    return true if (Time.now - self.orders.where("created_at >= ? and business = ?",Time.now.beginning_of_day,'1').last.created_at) > interval.hours
    false
  end

end