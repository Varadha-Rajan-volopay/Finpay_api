class UserPolicy < ApplicationPolicy
  def index?
    same_company? && user.admin?
  end

  def show?
    same_company? && (
      user.admin? || user.id == record.id
    )
  end

  def update?
    same_company? && user.id == record.id
  end

  def destroy?
    same_company? && user.admin?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.none unless user

      if user.admin?
        scope.where(company_id: user.company_id)
      else
        scope.where(
          id: user.id,
          company_id: user.company_id
        )
      end
    end
  end

  private

  def same_company?
    user.present? &&
      record.respond_to?(:company_id) &&
      user.company_id == record.company_id
  end
end
