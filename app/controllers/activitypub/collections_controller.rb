# frozen_string_literal: true

class ActivityPub::CollectionsController < ActivityPub::BaseController
  include SignatureVerification
  include AccountOwnedConcern

  before_action :require_signature!, if: :authorized_fetch_mode?
  before_action :set_items
  before_action :set_size
  before_action :set_type
  before_action :set_cache_headers

  def show
    expires_in 3.minutes, public: public_fetch_mode?
    render_with_cache json: collection_presenter, content_type: 'application/activity+json', serializer: ActivityPub::CollectionSerializer, adapter: ActivityPub::Adapter, skip_activities: true
  end

  private

  def set_items
    case params[:id]
    when 'featured'
      @items = begin
        # Because in public fetch mode we cache the response, there would be no
        # benefit from performing the check below, since a blocked account or domain
        # would likely be served the cache from the reverse proxy anyway

        if authorized_fetch_mode? && !signed_request_account.nil? && (@account.blocking?(signed_request_account) || (!signed_request_account.domain.nil? && @account.domain_blocking?(signed_request_account.domain)))
          []
        else
          cache_collection(@account.pinned_statuses.not_local_only, Status)
        end
      end
    when 'devices'
      @items = @account.devices
    else
      not_found
    end
  end

  def set_size
    case params[:id]
    when 'featured', 'devices'
      @size = @items.size
    else
      not_found
    end
  end

  def set_type
    case params[:id]
    when 'featured'
      @type = :ordered
    when 'devices'
      @type = :unordered
    else
      not_found
    end
  end

  def collection_presenter
    ActivityPub::CollectionPresenter.new(
      id: account_collection_url(@account, params[:id]),
      type: @type,
      size: @size,
      items: @items
    )
  end
end
