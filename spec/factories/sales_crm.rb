# Custom (MyDesk): Sales CRM factories
FactoryBot.define do
  factory :crm_pipeline, class: 'SalesCrm::Pipeline' do
    account
    sequence(:name) { |n| "Pipeline #{n}" }
    currency { 'SAR' }

    transient do
      with_stages { true }
    end

    after(:create) do |pipeline, evaluator|
      next unless evaluator.with_stages

      [['عميل محتمل', 10, :open], ['مؤهل', 25, :open], ['تم إرسال العرض', 50, :open], ['تفاوض', 75, :open],
       ['مكسوبة', 100, :won], ['خاسرة', 0, :lost]].each_with_index do |(name, probability, kind), index|
        pipeline.stages.create!(account: pipeline.account, name: name, probability: probability, kind: kind, position: index)
      end
      pipeline.stages.reload
    end
  end

  factory :crm_stage, class: 'SalesCrm::Stage' do
    pipeline factory: %i[crm_pipeline], with_stages: false
    account { pipeline.account }
    sequence(:name) { |n| "Stage #{n}" }
    probability { 10 }
    kind { :open }
    sequence(:position)
  end

  factory :crm_deal, class: 'SalesCrm::Deal' do
    account
    pipeline { association :crm_pipeline, account: account }
    stage { pipeline.stages.find(&:open?) || pipeline.first_open_stage }
    sequence(:title) { |n| "Deal #{n}" }
    amount_cents { 100_000 }
    close_date { Date.current + 30 }
    currency { 'SAR' }
    status { :open }
  end

  factory :crm_task, class: 'SalesCrm::Task' do
    account
    sequence(:title) { |n| "Task #{n}" }
    status { :open }
  end

  factory :crm_note, class: 'SalesCrm::Note' do
    account
    deal { association :crm_deal, account: account }
    content { 'note' }
  end
end
