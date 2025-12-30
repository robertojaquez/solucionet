using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141104)]
	public class _202501141104_create_man_paginas_t_aft_upd : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("man_paginas_t_aft_upd.sql");
		}

		public override void Down()
		{
		}
	}
}
