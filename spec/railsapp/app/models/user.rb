class User < ApplicationRecord

  notifyable

  belongs_to :company

end
