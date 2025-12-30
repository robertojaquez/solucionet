using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141028)]
	public class _202501141028_create_man_det_tabs_paginas_v : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("man_det_tabs_paginas_v.sql");
		}

		public override void Down()
		{
		}
	}
}
