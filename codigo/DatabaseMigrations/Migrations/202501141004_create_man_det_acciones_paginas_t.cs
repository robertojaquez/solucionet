using FluentMigrator;

namespace DatabaseMigrations.Migrations
{
   [Migration(202501141004)]
	public class _202501141004_create_man_det_acciones_paginas_t : FluentMigrator.Migration
	{
		public override void Up()
		{
			Execute.Script("man_det_acciones_paginas_t.sql");
		}

		public override void Down()
		{
		}
	}
}
