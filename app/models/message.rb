class Message < ActiveRecord::Base

  scope :overview, where("level in ('warn', 'error', 'fatal')")
  scope :recent, order('id desc').limit(50)
  
  def self.series(source)
    Message.where('source=?', source).order('id desc').limit(50)
  end

  def self.all(source)
    Message.where('source=?', source).order('id desc').limit(3000).all.reverse
  end

end
