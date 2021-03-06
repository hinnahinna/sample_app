# frozen_string_literal: true

class User < ApplicationRecord
  has_many :microposts, dependent: :destroy
  has_many :active_relationships, class_name: 'Relationship',
                                  foreign_key: 'follower_id',
                                  dependent: :destroy
  has_many :passive_relationships, class_name: 'Relationship',
                                   foreign_key: 'followed_id',
                                   dependent: :destroy
  # :sourceパラメーターを使って、「following配列の元はfollowed idの集合である」ということを明示的にRailsに伝えている
  has_many :following, through: :active_relationships, source: :followed
  has_many :followers, through: :passive_relationships, source: :follower

  # before_save { self.email = self.email.downcase }
  # before_save { self.email = email.downcase }

  attr_accessor :remember_token, :activation_token, :reset_token
  # before_save { email.downcase! }
  before_save :downcase_email
  before_create :create_activation_digest

  validates :name,  presence: true, length: { maximum: 50 }
  # ドッド２つ未対応 VALID_EMIAL_REGEX = /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i
  VALID_EMIAL_REGEX = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i.freeze
  validates :email, presence: true, length: { maximum: 255 },
                    format: { with: VALID_EMIAL_REGEX },
                    # uniqueness: true
                    uniqueness: { case_sensitive: false }
  has_secure_password
  validates :password, presence: true, length: { minimum: 6 }, allow_nil: true

  # test_fixtureにも使用
  def self.digest(string)
    # Ruby的に正しい書き方
    # def self.digest(string)
    cost = ActiveModel::SecurePassword.min_cost ? BCrypt::Engine::MIN_COST :
                                                  BCrypt::Engine.cost
    BCrypt::Password.create(string, cost: cost)
  end

  # ランダムなトークンを返す
  def self.new_token
    # Ruby的に正しい書き方
    # def self.new_token
    SecureRandom.urlsafe_base64
  end

  # permanent_sessionのためにUserをDBに保存
  def remember
    self.remember_token = User.new_token
    update_attribute(:remember_digest, User.digest(remember_token))
  end

  # 渡されたtokenがdigestと一致したらtrueを返却
  # def authenticated?(remember_token)
  def authenticated?(attribute, token)
    # digest = self.send("remember_digest")
    # digest = self.send("#{attribute}_digest") # selfは省略可
    digest = send("#{attribute}_digest")
    # 記憶digestがnilの際はfalseを返す
    # return false if remember_digest.nil?
    return false if digest.nil?

    # BCrypt::Password.new(remember_digest).is_password?(remember_token)
    BCrypt::Password.new(digest).is_password?(token)

    # 以下の書き方でも良い
    # if remember_digest.nil?
    #   false
    # else
    #   BCrypt::Password.new(remember_digest).is_password?(remember_token)
    # end
  end

  # delete login_information
  def forget
    update_attribute(:remember_digest, nil)
  end

  # account activation
  def activate
    # update_attribute(:activated, true)
    # update_attribute(:activated_at, Time.zone.now)
    # change 2line to 1line
    update_columns(activated: true, activated_at: Time.zone.now)
  end

  # send activation mail
  def send_activation_email
    UserMailer.account_activation(self).deliver_now
  end

  # configration password reset
  def create_reset_digest
    self.reset_token = User.new_token
    update_attribute(:reset_digest, User.digest(reset_token))
    update_attribute(:reset_sent_at, Time.zone.now)
  end

  def send_password_reset_email
    UserMailer.password_reset(self).deliver_now
  end

  def password_reset_expired?
    reset_sent_at < 2.hours.ago
  end

  def feed
    # 疑問符があることで、SQLクエリに代入する前にidがエスケープされるため、
    # SQLインジェクション (SQL Injection) と呼ばれる深刻なセキュリティホールを避けることができます。
    # この場合のid属性は単なる整数 (すなわちself.idはユーザーのid) であるため危険はありませんが、
    # SQL文に変数を代入する場合は常にエスケープする習慣をぜひ身につけてください。
    # Micropost.where('user_id = ?', id)
    # Micropost.where('user_id IN (?) OR user_id = ?', following_ids, id)
    following_ids = "SELECT followed_id FROM relationships
                     WHERE follower_id = :user_id"
    Micropost.where("user_id IN (#{following_ids})
                     OR user_id = :user_id", user_id: id)
  end

  # following user
  def follow(other_user)
    following << other_user
  end

  def unfollow(other_user)
    active_relationships.find_by(followed_id: other_user).destroy
  end

  def following?(other_user)
    following.include?(other_user)
  end

  private

  def downcase_email
    self.email = email.downcase
  end

  def create_activation_digest
    self.activation_token = User.new_token
    self.activation_digest = User.digest(activation_token)
  end
end
