using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141110)]
	public class _202501141110_insert_into_man_paginas_t : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("insert_into_man_paginas_t.sql");
		}

		public override void Down()
		{
		}
	}
}
