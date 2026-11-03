class ExpensePolicy < ApplicationPolicy
  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user

      if user.admin?
        scope.all
      else
        scope.where(user_id: user.id)
      end
    end
  end

  def index?
    user.present?
  end

  def show?
    same_user? || user.admin?
  end

  def create?
    user.present?
  end

  def update?
    return false unless record.pending?

    same_user? || user.admin?
  end

  def destroy?
    return false unless record.pending?

    same_user? || user.admin?
  end

  # Workflow permissions

  def approve?
    user.present? && user.admin? && !same_user?
  end

  def reject?
    user.present? && user.admin?
  end

  def reimburse?
    user.present? && user.admin?
  end

  def archive?
    user.present? && user.admin?
  end

  private

  def same_user?
    user.present? && record.user_id == user.id
  end
end
