# Custom (MyDesk): the CRM (Sales > Deals / Tasks), its own tables in MyDesk's database, scoped by account
module SalesCrm
  def self.table_name_prefix
    'crm_'
  end
end
